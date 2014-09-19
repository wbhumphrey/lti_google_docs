require_dependency "lti_google_docs/application_controller"
require_dependency "../../lib/lti_google_docs/GoogleDriveClient"

module LtiGoogleDocs::Api::V2
    class InstancesController < LtiGoogleDocs::ApplicationController
        def index
            instances = LabInstance.all
            
            render json: instances.to_json
        end
        
        def create
            puts params.inspect
            
            lab_id = params[:lab_id]
            result = {}
            
            if lab_id
                lab = Lab.find_by(id: lab_id)
                puts lab.inspect
                if !lab
                    puts "NO LAB FOUND FOR ID: #{lab_id}"
                    render json: result
                    return
                end
                
                
                #retrieve students enrolled in course
                puts "RETRIEVING STUDENTS ENROLLED IN COURSE"
                canvas_client.access_token = session[:canvas_access_token]
                lti_course_id = lab.course_id
                lti_course = Course.find_by(id: lti_course_id)
                students = canvas_client.list_students_in_course(lti_course.canvas_course_id)
                
                puts "STUDENTS RETRIEVED, INSPECTING..."
                puts students.inspect
                
                #retrieve lab instances
                instances = LabInstance.where(labid: lab_id)
                
                if instances.blank?
                    #there are no lab instances associated with this lab, ergo we need to create them
                    if !students.blank?
                        #possibility that there are students enrolled in the course
                        if students.kind_of?(Array)
                            #we have students, so we know we'll need to be creating some files on their drive account
                            
                            #validate our access token from google
                            validate_google_access_token(session)
                            
                            #get id of file to copy, associated with lab
                            id_of_file_to_copy = lab.folderId
                            
                            #get files from folder to be copied
                            files_from_folder_to_be_copied = drive.list_children(id_of_file_to_copy)
                            
                            puts files_from_folder_to_be_copied.inspect
                            
                            if !files_from_folder_to_be_copied.blank?
                                #there are files within the folder
                                puts "NUMBER OF STUDENTS: #{students.size}"
                                puts "NUMBER OF FILES: #{files_from_folder_to_be_copied.items.size}"
                                
                                #for every student enrolled in the course...
                                students.each do |student|
                                    title = "#{student['name']} - #{lab.title}"
                                    
                                    #create new folder for student
                                    id_of_new_folder = drive.create_folder(title)
                                    #share file (or try to)
                                    drive.share_file(student['id'], session[:userid], id_of_new_folder)
                                    
                                    #now that the folder is created, lets populate it with copied files
                                
                                    #for every file we need to copy
                                    files_from_folder_to_be_copied.items.each do |file|
                                        #get the meta data of the file
                                        file_data = drive.get_file_info(file.id)
                                        #grab the title from the meta data
                                        file_title = file_data.title
                                        #actually copy the file
                                        drive.copy_file(file.id, id_of_new_folder, file_title)
                                        
                                        #try to share the file with the student
                                        drive.share_file(student['id'], session[:userid], file.id)
                                    end
                                    
                                    #now we can create the lab instance
                                    lab_instance = LabInstance.create(labid: lab.id, studentid: student['id'], fileid: id_of_new_folder);
                                end 
                                
                                result = {students: students, lab_instances: LabInstance.where(labid: params[:id])}
                            else
                                #there are no files in the folder
                                puts "NO FILES WERE FOUND IN THE SPECIFIED FOLDER: #{lab.folderId}"
                                result = []
                                return
                            end
                        else
                            #we have an error message
                            if results["status"] == "unauthenticated"
                                render text: "NEEDS AUTHENTICATION!";
                                return;
                            end
                            #TODO handle other error messages
                            
                        end
                    else
                        #there are no students enrolled in the course
                        result = []
                    end
                else
                    #there are already lab instances
                    result = {students: students, instances: instances}
                end                
            else
                puts "NO IDEA HOW WE GOT HERE."
            end
            
            
            render json: result.to_json
        end
        
        def destroy
            instance_id = params["id"]
            
            if !instance_id
                puts "HOW DID WE GET HERE?!"
            else
                lab_instance = LabInstance.find_by(id: instance_id)
                if !lab_instance
                    puts "NO LAB INSTANCE FOR ID: #{instance_id}"
                else
                    lab_instance.destroy
                end
            end
            render json: {}, status: :no_content
        end
        
        def delete_all
            LabInstance.destroy_all
            
            render json: {}, status: :no_content
        end
    
        #======= UTILITIES
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