require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs
  class LaunchController < ApplicationController
    def index
        
        #get user id
        
        #check for refresh token mapping from user id
        
        #use refresh token to get auth token from google
        
        #Authorize?
        
        #render
        
        
        render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
    end
  end
end
