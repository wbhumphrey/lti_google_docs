require_dependency "lti_google_docs/application_controller"
require_dependency "../../lib/lti_google_docs/GoogleDriveClient"
module LtiGoogleDocs
  class Labs::InstancesController < ApplicationController
      
    def index
        @access_token = session[:google_access_token]
        @canvas_access_token = session[:canvas_access_token]
    end
      
    def all
        lis = LabInstance.all
        render json: lis.to_json
    end
    
    def show
        lab = Lab.find_by(id: params[:id])
        if !lab
            puts "NO LAB FOUND FOR ID: #{params[:id]}"
            render json: []
            return
        end
        
            
        silly_LI = LabInstance.where(labid: '10000')
        puts "JUST TO SEE HOW EMPTY ARRAYS ARE STRUCTURED"
        puts "BLANK? #{silly_LI.blank?}"
        puts "nil? #{!silly_LI}"
        puts silly_LI.inspect
      
        actual_LI = LabInstance.where(labid: params[:id])
        puts "JUST TO SEE HOW FULL ARRAYS ARE STRUCTURED"
        puts actual_LI.inspect
      
        canvas_client.access_token = session[:canvas_access_token]
        course = session["current_course_id"]
        students = canvas_client.list_students_in_course(course)
        puts "LISTING STUDENTS! (#{students.length})"
        
        students.each do |student|
            puts "FOUND: #{student['name']}"
        end
      
      
      
        li = LabInstance.where(labid: params[:id])
        if li.blank?
            puts "\nNO LAB INSTANCE FOUND - WE NEED TO CREATE ONE\n"

            puts session[:canvas_access_token]
#             puts session.inspect
            # GET ALL STUDENTS ENROLLED IN COURSE
            canvas_client.access_token = session[:canvas_access_token]
            course = session["current_course_id"]
            
            results = canvas_client.list_students_in_course(course)
            
            if !results.blank?
                if  results.kind_of?(Array)
                    # we actually got something...
                    
                    #google_client.access_token = session[:google_access_token]
                    
                    validate_google_access_token(session)
                
                    id_of_file_to_copy = lab.folderId

                    puts "ID OF FOLDER TO COPY: #{id_of_file_to_copy}"
                    # 1) List children of folder
                    child_list = drive.list_children(id_of_file_to_copy)
                    if !child_list.blank?

                        puts "LISTING CHILDREN SEEMED TO WORK OKAY"
                        puts "NUMBER OF STUDENTS: #{results.length}"
                        puts "NUMBER OF CHILD FILES: #{child_list.items.length}"

                        # FOR EVERY STUDENT IN COURSE
                        results.each do |result|
                           title = "#{result['name']} - #{lab.title}"
                            puts "TITLE OF NEW FOLDER: #{title}"
                        
                            # CREATE A NEW FOLDER
                            id_of_new_folder = drive.create_folder(title)

                            # SHARE FILE (OR AT LEAST TRY TO)
                            drive.share_file(result['id'], session[:userid], id_of_new_folder)

                            # FOR EVERY FILE IN FOLDER
                            child_list.items.each do |item|
                                puts "CHILD ID: #{item.id}"
                                puts item.inspect
                                
                                file_data = drive.get_file_info(item.id)
                                file_title = file_data.title
                                # MAKE A COPY OF FILE
                                drive.copy_file(item.id, id_of_new_folder, file_title)
                                
                                #share file if possible, otherwise add to set of files to shared with this user.
                                drive.share_file(result['id'], session[:userid], item.id);
                            end
                        
                            puts "CREATING LAB!"
                            li = LabInstance.create(labid: lab.id, studentid: result['id'], fileid: id_of_new_folder)
                            
                         end
                        
                        render json: LabInstance.where(labid: params[:id]).to_json
                        return
                    else
                        puts "SOMETHING WENT WRONG LISTING CHILDREN"
                    end

                    render json: results.to_json
                    return
                    
                else # NOT AN ARRAY
                    if results["status"] == "unauthenticated"
                        render text: 'NEEDS AUTHENTICATION!'
                        return
                        
                        #TODO: check for other statuses as well
                    end
                end
            else
                #no students enrolled in course
                render json: [].to_json
            end
            
            #remove this render line and replace with LabInstance to json
            render json: params.to_json
        else
            render json: li.to_json
        end
    end
    
    def remove
        id = params[:id]
        li = LabInstance.find_by(id: id)
        if !li
            puts "NO LAB INSTANCE FOUND WITH ID: #{id}"
        else
            
            if is_google_access_token_valid?(session[:google_access_token])
                puts "GOOGLE ACCESS TOKEN VALID IN LAB INSTANCE REMOVE"
            else
                u = User.find_by(id: session[:userid])
                if !u
                    puts "USER DOES NOT EXIST"
                else
                    puts "REFRESHING ACCESS TOKEN"
                    retrieve_access_token(u.refresh)
                end
            end
            
#            drive = google_client.discovered_api('drive', 'v2')
#            file_to_remove = li.fileid
#            
#            result = google_client.execute(:api_method => drive.files.delete,
#                                        :parameters => {'fileId' => file_to_remove})
#            
#            if result.status != 204
#                puts "ERROR DELETING FILE WITH ID: #{file_to_remove}"
#                puts "RESULT STATUS: #{result.status}"
#                puts result.body.inspect
#            else
#                puts "SUCCESSFUL DELETION!"
#            end
            
            drive.delete_file(li.fileid)
            
            
            puts "DELETING INSTANCE: #{li.inspect}"
            li.delete
        end
        
        render text: 'ok'
    end
    
    def drive
        return @drive_client if @drive_client
        
        @drive_client = LtiGoogleDocs::GoogleDriveClient.new(:google_client => google_client, :canvas_client => canvas_client)
        
        return @drive_client
    end

    def validate_google_access_token(session)
        if is_google_access_token_valid?(session[:google_access_token])
            puts "GOOGLE ACCESS TOKEN VALID!"
        else
            puts "GOOGLE ACCESS TOKEN INVALID! - CHECKING FOR USER WITH USERID: #{session[:userid]}"
            u = User.find_by(id: session[:userid])
            if !u
                puts "USER DOES NOT EXIST!"
            else
                puts "USER EXISTS, REFRESHING ACCESS TOKEN!"
                retrieve_access_token(u.refresh)
            end
        end
    end
  end
end
