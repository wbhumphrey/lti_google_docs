require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs::Api::V2
    class StudentsController < LtiGoogleDocs::ApplicationController
        def index
            
            api_token = request.headers["HTTP_LTI_API_TOKEN"]
            
            if !api_token
                render json: {error: 'Missing API token in LTI_API_TOKEN header'}.to_json, status: :bad_request
                return
            end
            
            u = User.find_by(api_token: api_token)
            if !u
                render json: {error: 'Invalid API token'}.to_json, status: :bad_request
                return
            end
            
            if !u.canvas_access_token
                render json: {error: 'Missing canvas_access_token'}.to_json, status: :bad_request
                return
            end
            
            puts "RETRIEVING LIST OF ENROLLED STUDENTS FROM CANVAS"
            
            lti_course_id = params[:course_id]
            lti_course = Course.find_by(id: lti_course_id)
            lti_client = Client.find_by(id: lti_course.client_id)
            
            # create canvas client from lti_client
            canvas_client = new_canvas_client(lti_client, request)
            canvas_client.access_token = lti_user.canvas_access_token
            
            #list students enrolled in this course from Canvas
            resulting_students = canvas_client.list_students_in_course(lti_course.canvas_course_id)
            
            # return list of student names, canvas_user_id's
            render json: resulting_students
            
        end
    
        def new_canvas_client(client, request)
            cc = LtiGoogleDocs::CanvasClient.new(client.canvas_url)
            cc.client_id = client.canvas_clientid
            cc.client_secret = client.canvas_client_secret
            
            host = request.headers['host'].split(':')[0]
            cc.redirect_uri = "https://#{host}:#{request.port}/lti_google_docs/register/confirmed2"
            
            return cc;
        end
    end
end
