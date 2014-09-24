require_dependency "lti_google_docs/application_controller"
require_dependency "../../lib/lti_google_docs/GoogleDriveClient"
require 'google/api_client'
require 'json'
require 'net/http'

module LtiGoogleDocs
  class RegisterController < ApplicationController
    CANVAS_AUTH_URL = "http://127.0.0.1:3000/login/oauth2/auth"  

    def confirmed
        puts "CONFIRMING!!!"
        puts params
    end
      
    def google
        puts "GOOGLING v2!!!"
        puts params

        client = google_client
        client.authorization.code = params[:code]
        client.authorization.grant_type = 'authorization_code'
        client.authorization.fetch_access_token!
        
        puts "REFRESH TOKEN: #{client.authorization.refresh_token}"
        puts "ACCESS TOKEN: #{client.authorization.access_token}"
       
        puts "CREATING STATE OBJECT!";
        state_object = {}
        csv_key_value_pairs = params[:state]
        key_value_pairs = csv_key_value_pairs.split(",")
        key_value_pairs.each do |x|
            tokens = x.split('=')
             key = tokens[0]
             value = tokens[1]
            state_object[key] = value
        end        
        puts "STATE OBJECT: "
        puts state_object.inspect
        
        puts "USER ID: #{state_object["canvas_user_id"]}"
        u = User.find_by(canvas_user_id: state_object["canvas_user_id"])
        if u
            u.refresh = client.authorization.refresh_token
            u.google_access_token = client.authorization.access_token
            u.save
        else
            u = User.create(canvas_user_id: state_object["canvas_user_id"],
                            refresh: client.authorization.refresh_token,
                            google_access_token: client.authorization.access_token)
        end

        # check for google email address
        if !u.email
            # update user with new refresh token
            info = get_google_user_info
            puts "UPDATING USER EMAIL TO: #{info['email']}"
            u.update_attributes(:refresh => client.authorization.refresh_token, :email => info['email'])
        end

        if state_object["needs_canvas"] != 'true'
            "PUTS CANVAS TOKEN NOT NEEDED, NO NEED TO REDIRECT THERE!";
            render "google_token_confirmation"
            return
        end
    
        # We redirect to a page that automatically closes itself
        # since this is redirected to a popup.
#        redirect_to "/lti_google_docs/register/confirmed"
        puts "REDIRECTING TO /lti_google_docs/register/canvas!";
      redirect_to "/lti_google_docs/register/canvas?domain=#{state_object['canvas_server_address']}&canvas_user_id=#{state_object['canvas_user_id']}&canvas_clientid=#{state_object['canvas_clientid']}"
    end
      
    
    def canvas
        
        
        host = request.headers["host"].split(':')[0]
        
        ps = {}
        if params[:canvas_clientid]
            ps[:client_id] = params[:canvas_clientid]
        else if params[:consumer_key]
            ps[:client_id] = params[:consumer_key]
        else
            ps[:client_id] = -1
        end
            
#        ps[:client_id] = params[:consumer_key]
        ps[:redirect_uri] = "https://#{host}:#{request.port}/lti_google_docs/register/confirmed2"
        ps[:response_type] = 'code'
        ps[:state] = "canvas_user_id=#{params[:canvas_user_id]},lti_client_id=#{params[:lti_client_id]}";
        query = ps.to_query
        url = URI.parse("https://#{params[:domain]}/login/oauth2/auth?#{query}")

        puts "REDIRECTING TO URL: #{url}"
        redirect_to "#{url}"
    end
        
    # This action is redirected to from Google's OAuth2 popup so that
    # we can retrieve OAuth tokens for Canvas
    def confirmed2
        puts "CONFIRMED 2!!!!!!!!"
        puts params.inspect
        
        code = params[:code]
        puts "RETRIEVAL CODE: #{code}"
        
        csv_key_value_pairs = params[:state]
        key_value_pairs = csv_key_value_pairs.split(',')
        
        state_object = {}
        key_value_pairs.each do |pair|
            tokens = pair.split('=')
            key = tokens[0];
            value = tokens[1];
            state_object[key] = value
        end
        
        if !state_object['lti_client_id']
            render json: {error: 'lti client id not passed through Canvas OAuth2 web flow!'}.to_json, status: :bad_request
            return
        end
        
        lti_client_id = state_object['lti_client_id']
        ### RETRIEVE CLIENT FROM lti_client_id ###
        lti_client = Client.find_by(id: lti_client_id)
        ### END RETRIEVE CLIENT ###
        
        canvas_user_id = state_object['canvas_user_id']
        client = new_canvas_client (lti_client)

        client.auth_code = code
        
        client.request_access_token!
        puts "ACCESS TOKEN: #{client.access_token}"
        
        canvas_user = User.find_by(canvas_user_id: canvas_user_id)
        if !canvas_user
            # create user
            canvas_user = User.create(canvas_user_id: canvas_user_id, canvas_access_token: client.access_token)
        else
            # update user
            canvas_user.canvas_access_token = client.access_token
            canvas_user.save
        end

        @confirmation_message = "Canvas Access Token has been saved! Thank you for your cooperation! Your window will close in 5 seconds. If you wish to close it sooner, click the green button below. You will need to reload the page, once this window closes."

        render "canvas_token_retrieval_confirmation";
    end
    
    def index
    end

    def get_google_user_info
        oauth2 = google_client.discovered_api('oauth2', 'v2')
        result = google_client.execute(:api_method => oauth2.userinfo.get)
        
        if result.status == 200
            puts "\nSUCCESSFUL GOOGLE USER INFO RETRIEVAL"
            puts result.data.inspect
        else
            puts "\nUNSUCCESSFUL GOOGLE USER INFO RETRIEVAL"
            puts result.data.inspect
        end
        
        return result.data
    end

    def drive
        return @drive_client if @drive_client
        @drive_client = LtiGoogleDocs::GoogleDriveClient.new(:google_client => google_client, :canvas_client => canvas_client)
        return @drive_client
    end

    def new_canvas_client(client)
        cc = LtiGoogleDocs::CanvasClient.new(client.canvas_url)
        cc.client_id = client.canvas_clientid
        cc.client_secret = client.canvas_client_secret

        #this needs to be domain_tool_is_running_on:port_tool_is_using/lti_google_docs/register/confirmed2
        cc.redirect_uri = "http://"+get_my_ip_address+":31337/lti_google_docs/register/confirmed2"
        return cc
    end

  end
end
