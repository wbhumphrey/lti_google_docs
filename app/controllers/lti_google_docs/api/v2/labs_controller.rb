require_dependency "lti_google_docs/application_controller"
require 'json'

module LtiGoogleDocs::Api::V2
    class LabsController < LtiGoogleDocs::ApplicationController
        
        def index
            labs = Lab.all
            render json: labs
        end
        
        #Entry point to LTI from Canvas
        def create
            # get custom_canvas_course_id from params
            custom_canvas_course_id = params["custom_canvas_course_id"]
            
            if !custom_canvas_course_id
                puts "NO CUSTOM CANVAS COURSE ID FOUND IN PARAMETERS. PERHAPS THE LTI TOOL IS CONFIGURED FOR LESS THAN PUBLIC ACCESS?"
                @course_id = -1
            else
            # get corresponding course object with custom_canvas_course_id
            # and assign to instance variable
                course = Course.find_by(canvas_course_id: custom_canvas_course_id)
                if !course
                    puts "NO COURSE FOUND FOR CANVAS COURSE WITH ID: #{custom_canvas_course_id}"
                    @course_id = -1
                else
                    @course_id = course.id
                end
            end
            
            puts "SENDING COURSE ID: #{@course_id}"
            render "lab_creator"
        end
        
        def new
            puts "INSIDE NEW"
            if request.post?
                if !params["course_id"]
                    puts "NO COURSE ID FOUND, FAILING GRACEFULLY"
                    render text: "No course id, no new lab."
                    return;
                end

                existing_lab = Lab.find_by(course_id: params["course_id"], title: params["title"])

                if !existing_lab
                    title = params[:title]
                    folderName = params[:folderName]
                    google_drive_folder_id = params[:folderId]
                    participation = params[:participation]

                    lab = Lab.create(title: title, folderName: folderName, folderId: google_drive_folder_id, participation: participation, course_id: params["course_id"])
                    
                    course_id = params["course_id"]
                    canvas_course = Course.find_by(id: course_id)
                    
                    client_id = canvas_course.client_id
                    canvas_course_id = canvas_course.canvas_course_id
                    client = Client.find_by(id: client_id)
                    key = client.client_id
                    secret = client.client_secret
                    canvas_client.access_token = session[:canvas_access_token]
                    url = "http://#{get_my_ip_address}:#{request.port}/lti_google_docs/api/v2/labs/#{lab.id}/launch"
                    tool_added = JSON.parse(canvas_client.add_tool_to_course_with_credentials(canvas_course_id, "(LAB) #{title}", url, key, secret))
                    puts tool_added.inspect
                    if tool_added["errors"]
                        puts "PROBLEM CREATING LAB, COULD NOT ADD TOOL!"
                        render json: [].to_json
                        return
                    end
                    puts "NEW TOOL ID: #{tool_added['id']}"
                    puts "CANVAS MODULE ID: #{canvas_course.canvas_module_id}"
                    #add entry to database
                    CanvasTools.create(labid: lab.id, canvas_tool_id: tool_added['id'])
                    
                    #now add the tool to our course's module "labs"
                    json_result = canvas_client.add_tool_to_course_module(canvas_course_id, canvas_course.canvas_module_id, tool_added["id"], title, url)
                    operation_result = JSON.parse(json_result)
                    
                    if !operation_result["errors"]
                        #worked like a charm!
                        puts "ADDED LAB TO MODULE SUCCESSFULLY!"
                    else
                        puts "THERE WERE ERRORS ADDING NEW LAB TO OUR MODULE"
                    end
                    
                    puts "SUCCESSFUL LAB CREATION!"
                    render json: lab.to_json
                else
                    #lab already exists, render it as json
                    puts "LAB ALREADY EXISTS, NEW LAB NOT CREATED."
                    render json: existing_lab.to_json
                end
            else
                render text: "no GET requests."
            end
        end
        
        def destroy
            lab_id = params["id"]
            
            if !lab_id
                puts "HOW IN GODS GREEN EARTH DID WE GET HERE?"
            else
                lab = Lab.find_by(id: lab_id)
                course = Course.find_by(id: lab.course_id).canvas_course_id
                if lab
                    puts "DESTROYING LAB"
                    lab.destroy
                    
                    #also destroy any associated tools
                    puts "RETRIEVING ANY LINGERING LTIs IN CANVAS"
                    tool = CanvasTools.find_by(labid: lab_id)
                    
                    if tool
                        canvas_client.access_token = session[:canvas_access_token]
                        #remove tool from canvas
                        puts "REMOVING LTI FROM CANVAS"
                        canvas_client.remove_tool_from_course(course, tool.canvas_tool_id)

                        #do we need to iterate through every module as well?

                        #delete entry in database
                        puts "DESTROYING TOOL"
                        tool.destroy
                    end
                    
                else
                    puts "NO LAB AT ID: #{lab_id}"
                end
            end
            
            render json: {}, status: :no_content
        end
        
        def launch
            puts params.inspect
            
            @lab_id = params[:lab_id]
            student_id = params[:custom_canvas_user_id]
            
            # sanity check, if no lab @ lab_id exists, OR params[:lab_id] isn't present, return error code
            
            # sanity check, if no user @ custom_canvas_user_id exists OR params[:custom_canvas_user_id] is not present, return error code
            
            instances = LabInstance.where(labid: @lab_id)
            # if any lab instance with this lab id exists...
            if !instances.blank?
                # if i am not a student
                if !tool_provider.student?
            
                    # retrieve all students names
                    #show instructor/designer view
                    render "designer_lab"
                # if i AM a student
                else
                    # retrieve lab instance with this id and my student_id
                    lab_instance = LabInstance.find_by(labid: @lab_id, studentid: student_id)
                    if lab_instance
                    # validate google token
                        validate_google_access_token(session)
                    # retrieve shared_folder_id from labinstance
                        shared_folder_id = lab_instance.fileid
                    # retrieve list of files from shared folder
                        shared_files_json = drive.list_children(shared_folder_id)
                    # generate object via JSON.generate from list of files (as json)
                    # put generated object in cookie with key 'shared_files'
                        cookies["shared_files"] = JSON.generate(shared_files_json)
                    # show 'student_lab'
                        render "student_lab"
                    else
                        #no lab instance exists for this student. Was the student enrolled after lab creation?
                    end
                end
            else
            # if no lab instance exists
                if !tool_provider.student?
                # if I am not a student
                    #show designer_lab_activation
                    render "designer_lab_activation"
                else
                # if I AM a student
                    #show message to notify instructor that they need to login
                    render text: "Please notify your instructor that they need to login before this lab is activated"
                end
            end
        end
        
        def validate_google_access_token(session)
            if is_google_access_token_valid?(session[:google_access_token])
                #token is valid
            else
                #token is not valid, we need to refresh it.
                #start by retrieving user credentials for the user of this session
                puts "TOKEN IS INVALID, REFRESHING TOKEN"
                user = User.find_by(id: session[:userid])
                if !user
                    #user does not exist
                    puts "TRYING TO REFRESH GOOGLE ACCESS TOKEN, BUT NO USER IS ASSOCIATED WITH SESSION"
                else
                    #user exists
                    session[:google_access_token] = retrieve_access_token(user.refresh)
                    puts "ACCESS TOKEN REFRESHED"
                end
            end
        end
    
        def drive
            return @drive_client if @drive_client
            @drive_client = LtiGoogleDocs::GoogleDriveClient.new(:google_client => google_client, :canvas_client => canvas_client)
            
            return @drive_client
        end
    
    
    end
end