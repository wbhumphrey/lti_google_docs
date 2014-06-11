require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs
  class LaunchController < ApplicationController
    CLIENT_ID = "558678724881-mnbk8edutlbrkvk7tu0v00cpqucp1j15.apps.googleusercontent.com"
    CLIENT_SECRET = "E007PYt5yNSaFVwfRjLV2AiB"
    REDIRECT_URI = "http://desolate-reef-8522.herokuapp.com/lti_google_docs/register/google"
    REDIRECT_URI = "http://127.0.0.1:31337/lti_google_docs/register/google"
    SCOPES = ['https://www.googleapis.com/auth/drive']
        
    #The initial loading point for our LTI
    def index
        #check for Google Access Token in session
        session[:userid] = params[:user_id]
         if is_access_token_valid?
            #yes => proceed as normal
            puts "ACCESS TOKEN FOUND, NOTHING TO SEE HERE"
            @access_token = session[:google_access_token]
        else
            #no => check User for refresh token given userid
            puts "NO ACCESS TOKEN FOUND...LOOKING FOR REFRESH TOKEN"
            @u = User.find_by(userid: params[:user_id])
            if !@u || !@u.refresh
                #no => redirect with popup and so forth...
                puts "NO REFRESH TOKEN FOUND, SENDING POPUP"
                session[:userid] = params[:user_id]
            else
                #yes => retrieve access token, store in session, proceed as normal
                # if something bad happens here, it's likely a bad refresh token
                # so we will set the user's refresh token to nil, set the access token
                # to nil and re-authenticate/authorize
                begin
                    puts "REFRESH TOKEN FOUND, RETRIEVING ACCESS TOKEN!"
                    refreshToken = @u.refresh
                    @access_token = retrieve_access_token(refreshToken)
                    puts "ACCESS TOKEN RETRIEVED: #{@access_token} ... STORING IN SESSION"
                    session[:google_access_token] = @access_token
                rescue
                    puts "SOMETHING BAD HAPPENED..."
                    puts "REMOVING CURRENT REFRESH TOKEN..."
                    User.find_by(userid: session[:userid]).update_attributes(:refresh => nil)
                    
                    @access_token = nil
                end
            end
        end

        render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
    end
      
    #The initial page will load a window up directed to this action.
    def auth
        
        puts "params from auth: #{params}"
        puts "SESSION IN AUTH: #{session[:userid]}"
        ps = {};
        ps[:redirect_uri] = REDIRECT_URI
        ps[:client_id] = CLIENT_ID
        ps[:scope] = SCOPES[0]
        ps[:immediate] = false
        ps[:approval_prompt] = 'force'
        ps[:response_type] = 'code'
        ps[:access_type] = 'offline'
        ps[:state] = '0xDEADBEEF'

        query = ps.to_query
        redirect_to "https://accounts.google.com/o/oauth2/auth?#{query}"
    end

    def hello
        
        puts "TOKEN: #{session[:google_access_token]}"
        client = Google::APIClient.new
        client.authorization.client_id = CLIENT_ID
        client.authorization.client_secret = CLIENT_SECRET
        client.authorization.access_token = session[:google_access_token]
        client.authorization.scope = SCOPES[0]
        drive = client.discovered_api('drive', 'v2')
        api_result = client.execute(
            :api_method => drive.files.list,
            :parameters => {});
        
        #puts api_result.inspect
        result = Array.new
        if api_result.status == 200
                files = api_result.data
                
                result.concat(files.items)
                puts "RESULTS: #{result.inspect}"
        else
            puts "DIDN'T WORK SO REFRESHING ACCESS TOKEN"
            puts "LOOKING FOR USER WITH ID: #{session[:userid]}"
            
            
            refreshToken = User.find_by(userid: session[:userid]).refresh
            accessToken = retrieve_access_token(refreshToken)
            puts "RETRIEVED TOKEN: #{accessToken} ... PUTTING IN SESSION"
            session[:google_access_token] = accessToken
            
            client.authorization.access_token = accessToken
            drive = client.discovered_api('drive', 'v2')
            api_result = client.execute(:api_method => drive.files.list,
                                        :parameters => {});
            puts "RESULT FOR TRY 2: #{api_result.status}"
            if api_result.status == 200
                files = api_result.data
                result.concat(files.items)
            end
        end    
        
        render json: result
    end

    def is_access_token_valid?
        if !session[:google_access_token] then return false end
    
        client = Google::APIClient.new
        client.authorization.client_id = CLIENT_ID
        client.authorization.client_secret = CLIENT_SECRET
        client.authorization.access_token = session[:google_access_token]
        client.authorization.scope = SCOPES[0]
        drive = client.discovered_api('drive', 'v2')
        api_result = client.execute(
            :api_method => drive.files.list,
            :parameters => {});
        
        if api_result.status != 200
            return false
        end
            
        return true
    end

    def retrieve_access_token(refresh_token)
        client = Google::APIClient.new
        client.authorization.client_id = CLIENT_ID
        client.authorization.client_secret = CLIENT_SECRET
        client.authorization.refresh_token = refresh_token
        
        client.authorization.grant_type = 'refresh_token'
        
        client.authorization.fetch_access_token!
        
        client.authorization.access_token
    end
        
        
    def factory
    end
        
    def files
        hello
    end
  end
end
