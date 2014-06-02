require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs
  class RegisterController < ApplicationController
    def index
        
        if !params[:google_auth]
            render text: "No Google?";
        else
            render text: 'Hello Register!'
        end
    end
  end
end
