require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs::Api::V2
    class CoursesController < LtiGoogleDocs::ApplicationController
        def index
            
            if params["list"]
                render json: Course.all.to_json
                return
            end
            
            
            render "courses"
        end
        
        def destroy
            id = params["id"]
            course = Course.find_by(id: id)
            if course
                course.destroy
                render json: Course.all.to_json
            else
                render text: "NO COURSE TO DELETE"
            end
            
        end
    end
end