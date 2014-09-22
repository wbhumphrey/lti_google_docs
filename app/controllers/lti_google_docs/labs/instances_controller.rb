require_dependency "lti_google_docs/application_controller"
require_dependency "../../lib/lti_google_docs/GoogleDriveClient"
module LtiGoogleDocs
  class Labs::InstancesController < ApplicationController
      
    def index
        render text: "Not Implemented Yet."
    end
      
    def all
        lis = LabInstance.all
        render json: lis.to_json
    end
    
    def show
        render text: "Not Implemented yet."
    end
    
    def remove
        
        render text: "Not Implemented Yet."
    end
  end
end
