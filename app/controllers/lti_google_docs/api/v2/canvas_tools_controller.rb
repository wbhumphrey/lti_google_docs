require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs::Api::V2
    class CanvasToolsController < LtiGoogleDocs::ApplicationController
        def index
            render json: CanvasTools.all
        end
    end
end