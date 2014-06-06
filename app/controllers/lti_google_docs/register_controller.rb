require_dependency "lti_google_docs/application_controller"
require 'google/api_client'
require 'json'

module LtiGoogleDocs
  class RegisterController < ApplicationController
    CLIENT_ID = "558678724881-mnbk8edutlbrkvk7tu0v00cpqucp1j15.apps.googleusercontent.com"
    CLIENT_SECRET = "E007PYt5yNSaFVwfRjLV2AiB"
    REDIRECT_URI = "http://desolate-reef-8522.herokuapp.com/lti_google_docs/register/google"
    REDIRECT_URI = "http://127.0.0.1:31337/lti_google_docs/register/google"
    SCOPES = ['https://www.googleapis.com/auth/drive']
      
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
      
        if User.find_by(userid: session[:userid])
            puts "FOUND EXISTING USER, UPDATING ENTRY"
            User.find_by(userid: session[:userid]).update_attributes(:refresh => client.authorization.refresh_token)
        else    
            puts "NO EXISTING USER FOUND, CREATING ENTRY"
            User.create(userid: session[:userid], refresh: client.authorization.refresh_token);
        end

        # We redirect to a page that automatically closes itself
        # since this is redirected to a popup.
        redirect_to "/lti_google_docs/register/confirmed"
    end
      
    def index
    end
      
  end
end
