require_dependency "lti_google_docs/application_controller"

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
                    
                    id_of_file_to_copy = lab.folderId
                
                    drive = google_client.discovered_api('drive', 'v2')

                    puts "ID OF FOLDER TO COPY: #{id_of_file_to_copy}"
                    # 1) List children of folder

                    
                
                    child_list_result = google_client.execute(
                        :api_method => drive.children.list,
                        :parameters => { 'folderId' => id_of_file_to_copy})
                    if child_list_result.status == 200
                        puts "LISTING CHILDREN SEEMED TO WORK OKAY"
                        puts "NUMBER OF STUDENTS: #{results.length}"
                        puts "NUMBER OF CHILD FILES: #{child_list_result.data.items.length}"

                        # FOR EVERY STUDENT IN COURSE
                        results.each do |result|
                           title = "#{result['name']} - #{lab.title}"
                            puts "TITLE OF NEW FOLDER: #{title}"
                        
                            # CREATE A NEW FOLDER
                            id_of_new_folder = create_folder(title)

                            # SHARE FILE (OR AT LEAST TRY TO)
                            share_file(result['id'], session[:userid], id_of_new_folder)

                            # FOR EVERY FILE IN FOLDER
                            child_list_result.data.items.each do |item|
                                puts "CHILD ID: #{item.id}"
                                puts item.inspect
                                
                                file_data = get_file_info(item.id)
                                file_title = file_data.title
                                # MAKE A COPY OF FILE
                                copy_file(item.id, id_of_new_folder, file_title)
                                
                                #share file if possible, otherwise add to set of files to shared with this user
                                #TODO.
                                
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
            
            drive = google_client.discovered_api('drive', 'v2')
            file_to_remove = li.fileid
            
            result = google_client.execute(:api_method => drive.files.delete,
                                        :parameters => {'fileId' => file_to_remove})
            
            if result.status != 204
                puts "ERROR DELETING FILE WITH ID: #{file_to_remove}"
                puts "RESULT STATUS: #{result.status}"
                puts result.body.inspect
            else
                puts "SUCCESSFUL DELETION!"
            end
            
            
            puts "DELETING INSTANCE: #{li.inspect}"
            li.delete
        end
        
        render text: 'ok'
    end
    
    def create_folder(name)
        drive = google_client.discovered_api('drive', 'v2')
        new_folder = drive.files.insert.request_schema.new({
                        'title'=> "#{name}",
                        'mimeType' => 'application/vnd.google-apps.folder'
                        })
                
        result = google_client.execute(
            :api_method => drive.files.insert,
            :body_object => new_folder)

        if result.status == 200
            puts "FOLDER CREATION SEEMED TO WORK OKAY"
            puts result.data.inspect
            return result.data.id
        else
            puts "SOMETHING HAPPENED WITH FOLDER CREATION"

            puts result.data.inspect
            return -1
        end
    end

    def get_file_info(id) 
        drive = google_client.discovered_api('drive', 'v2')
        result = google_client.execute(:api_method => drive.files.get, :parameters => { 'fileId' => id})
        
        if result.status == 200
            puts "FILE INFO RETRIEVAL SEEMED TO GO OKAY"
            return result.data
        else
            puts "SOMETHING WENT WRONG WHEN RETRIEVING FILE INFO"
            return -1
        end
    end

    def copy_file(fileid, parentid, title)
        drive = google_client.discovered_api('drive', 'v2')
        
        copy_of_file = drive.files.copy.request_schema.new({
            'title' => title,
            'parents' => [{ 'id' =>parentid}]
            })
        
        result = google_client.execute(
            :api_method => drive.files.copy,
            :body_object => copy_of_file,
            :parameters => { 'fileId' => fileid})
        
        if result.status == 200
            puts "FILE COPY SEEMED TO WORK OKAY"
            return result.data
        else
            puts "SOMETHING WENT WRONG WHEN COPYING FILE"
            return -1
        end
        
    end

    def get_drive_user_info
        drive = google_client.discovered_api('drive', 'v2')
        about_result = google_client.execute(:api_method => drive.about.get)
        if about_result.status == 200
            puts "ACCESSING DRIVE OF USER: #{about_result.data.name}"
        else
            puts "SOMETHING WENT WRONG ACCESSING USER INFO"
        end
    end

    def get_permissions_for_file(id)
        drive = google_client.discovered_api('drive', 'v2')
        perms_result = google_client.execute(:api_method=>drive.permissions.list, :parameters => {'fileId' => id})
        if perms_result.status == 200
            puts "PERMISSIONS LISTING SEEMED TO WORK OKAY"
        else
            puts "SOMETHING WENT WRONG WITH PERMISSION LISTING"
        end
    end

    def list_all_files_on_drive
        drive = google_client.discovered_api('drive', 'v2')
        api_result = google_client.execute(:api_method => drive.files.list, :parameters => {})
        if api_result.status == 200
            puts "FILE LISTING SEEMED TO WORK OKAY"
        else
            puts "SOMETHING WENT WRONG WITH FILE LISTING"
        end
    end

    def touch_file(id)
        drive = google_client.discovered_api('drive', 'v2')
        touch_result = google_client.execute(
            :api_method => drive.files.touch,
            :parameters =>{'fileId' => id})
        if touch_result.status == 200
            puts "TOUCHING FILE SEEMED TO WORK OKAY"
        else
            puts "SOMETHING WENT WRONG TOUCHING FILE"
            puts touch_result.data
        end
    end



    def send_file_to_trash(id)
        drive = google_client.discovered_api('drive', 'v2')
        trash_result = google_client.execute(
            :api_method => drive.files.trash,
            :parameters => {'fileId' => id})
        if trash_result.status == 200
            puts "TRASHING FILE SEEMED TO WORK OKAY"
        else
            puts "SOMETHING WENT WRONG TRASHING FILE"
        end
    end

    def recover_file_from_trash(id)
        drive = google_client.discovered_api('drive', 'v2')
        untrash_result = google_client.execute(
            :api_method => drive.files.untrash,
            :parameters => {'fileId' => id})

        if untrash_result.status == 200
            puts "UNTRASHING FILE SEEMED TO WORK OKAY"
        else
            puts "SOMETHING WENT WRONG UNTRASHING FILE"
        end
    end

    def list_parents_of_file(id)
        drive = google_client.discovered_api('drive', 'v2')
        list_parents_result = google_client.execute(
            :api_method => drive.parents.list,
            :parameters => {'fileId' => id})

        primary_parent = "asdf"
        if list_parents_result.status == 200
            puts "LISTING PARENTS SEEMED TO WORK OKAY"
            parents = list_parents_result.data
            parents.items.each do |parent|
                puts "Parent File Id: #{parent.id}"
                primary_parent = parent.id
            end
        else
            puts "SOMETHING WENT WRONG LISTING PARENTS"
        end
    end

    def share_file_on_drive(id, email)
        drive = google_client.discovered_api('drive', 'v2')
        new_permission = drive.permission.insert.request_schema.new({
            'value' => email,
            'type' => 'user',
            'role' => 'writer'
        })
        
        result = client.execute(
            :api_method => drive.permissions.insert,
            :body_object => new_permission,
            :parameters => {'fileId' => id})
        
        if result.status == 200
            puts "PERMISSION INSERTION SUCCESSFUL!"
            puts result.data.inspect
        else
            puts "PERMISSION INSERTION UNSUCCESSFUL"
            puts result.status
            puts result.data.inspect
        end
    end

    def share_file(to, from, fileid)
        #Get id of user we're sharing to -> should be in result["id"]
        student_id = to
        #Get user from id
        student = User.find_by(id: student_id)
        if student
            #if user exists...get email
           if student.email 
                #if email exists, do share
               share_file_on_drive(fileid, student.email)
            else
                #if email does not exist, send message via conversation
               puts "STUDENT #{student_id} HAS NOT LOGGED IN YET...ADDING REQUEST TO TABLE...SENDING MESSAGE"
               ShareRequests.create(creator: from, for: student_id, file_id: fileid)
                canvas_client.start_conversation(student_id, 'One or more files have been shared with you on Google Drive. Please log in to MU Labs to view.')

            end
        else
             #if user does not exist, add to ShareRequests table
            puts "STUDENT: #{student_id} DOES NOT EXIST...ADDING REQUEST TO TABLE...SENDING MESSAGE."
            ShareRequests.create(creator: from, for: student_id, file_id: fileid)
            canvas_client.start_conversation(student_id, 'One or more files have been shared with you on Google Drive. Please log in to MU Labs to view.')
        end
    
    end

  end
end
