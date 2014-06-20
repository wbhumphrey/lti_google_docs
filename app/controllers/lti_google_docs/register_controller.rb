require_dependency "lti_google_docs/application_controller"
require 'google/api_client'
require 'json'
require 'net/http'

module LtiGoogleDocs
  class RegisterController < ApplicationController
    CLIENT_ID = "558678724881-mnbk8edutlbrkvk7tu0v00cpqucp1j15.apps.googleusercontent.com"
    CLIENT_SECRET = "E007PYt5yNSaFVwfRjLV2AiB"
    REDIRECT_URI = "http://desolate-reef-8522.herokuapp.com/lti_google_docs/register/google"
    REDIRECT_URI = "http://127.0.0.1:31337/lti_google_docs/register/google"
    SCOPES = ['https://www.googleapis.com/auth/drive']
      
    CANVAS_AUTH_URL = "http://127.0.0.1:3000/login/oauth2/auth"  
    CANVAS_CLIENT_SECRET = "fznpV0Tl9GCjmaPBBvnFNUlz7zkvURu7GRtbXUi4ORsJX955EdoK0bvbnL65a0gZ"
    CANVAS_CLIENT_ID = 2
    CANVAS_REDIRECT_URI = "http://127.0.0.1:31337/lti_google_docs/register/confirmed2"
    def confirmed
        puts "CONFIRMING!!!"
        puts params
    end
      
    def google
        puts "GOOGLING!!!"
        puts params
        
        client = Google::APIClient.new
        client.authorization.client_id = CLIENT_ID
        client.authorization.client_secret = CLIENT_SECRET
        client.authorization.code = params[:code]
        client.authorization.redirect_uri = REDIRECT_URI
        client.authorization.grant_type = 'authorization_code'

        client.authorization.fetch_access_token!
        
        puts "REFRESH TOKEN: #{client.authorization.refresh_token}"
        puts "ACCESS TOKEN: #{client.authorization.access_token}"
        puts "USER ID: #{session[:userid]}"
        session[:google_access_token] = client.authorization.access_token  
      
      
        if User.find_by(userid: session[:userid])
            puts "FOUND EXISTING USER, UPDATING ENTRY"
            User.find_by(userid: session[:userid]).update_attributes(:refresh => client.authorization.refresh_token)
        else    
            puts "NO EXISTING USER FOUND, CREATING ENTRY"
            User.create(userid: session[:userid], refresh: client.authorization.refresh_token);
        end

        # We redirect to a page that automatically closes itself
        # since this is redirected to a popup.
#        redirect_to "/lti_google_docs/register/confirmed"
      redirect_to "/lti_google_docs/register/canvas"
    end
      
    
    def canvas
        ps = {}
        ps[:client_id] = 2
        ps[:redirect_uri] = 'http://127.0.0.1:31337/lti_google_docs/register/confirmed2'
        ps[:response_type] = 'code'

        query = ps.to_query
        url = URI.parse("#{CANVAS_AUTH_URL}?#{query}")

        redirect_to "#{url}"
    end
        
    # This action is redirected to from Google's OAuth2 popup so that
    # we can retrieve OAuth tokens for Canvas
    def confirmed2
        code = params[:code]
        puts "RETRIEVAL CODE: #{code}"
        client = CanvasClient.new("http://127.0.0.1:3000")
        client.client_id = CANVAS_CLIENT_ID
        client.redirect_uri = CANVAS_REDIRECT_URI
        client.client_secret = CANVAS_CLIENT_SECRET
        client.auth_code = code
        
        client.request_access_token!
        puts "ACCESS TOKEN: #{client.access_token}"
        
        session[:canvas_access_token] = client.access_token
        puts client.list_courses
        puts client.list_students_in_course(1)
        # THE BELOW COMMAND IS VERIFIED TO WORK
        #client.add_tool_to_course(1, "Test Tool", CANVAS_REDIRECT_URI)
        
        render text: "ok"
    end
    
    def index
    end

      
  end


end
