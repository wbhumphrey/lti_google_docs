require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs
  class LaunchController < ApplicationController
    def index
        
        #get user id
        
        #check for access token mapping from user id
         #if no access token,
            #check for refresh token mapping from user id
             #if no refresh token,
                #load unauthenticated view with automatic token retrieval 
             #else
                #retrieve access token via refresh token
                #load authenticated view
         #else 
            #load authenticated view
        
        #render
        
        
        render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
    end
  end
end
