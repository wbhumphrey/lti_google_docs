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
        render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
    end
      
    #The initial page will load a window up directed to this action.
    def auth
        params = {};
        params[:redirect_uri] = REDIRECT_URI
        params[:client_id] = CLIENT_ID
        params[:scope] = SCOPES[0]
        params[:immediate] = false
        params[:approval_prompt] = 'force'
        params[:response_type] = 'code'
        params[:access_type] = 'offline'

        query = params.to_query
        @variable = 'something'
        redirect_to "https://accounts.google.com/o/oauth2/auth?#{query}"
    end
  end
end
