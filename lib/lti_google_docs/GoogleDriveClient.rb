module LtiGoogleDocs
    class GoogleDriveClient
        
        def initialize(options = {})
            puts "INSIDE GOOGLE DRIVE CLIENT"
            #puts options.inspect
            
            @google_client = options[:google_client]
            @canvas_client = options[:canvas_client]
            puts "GOOGLE CLIENT: #{@google_client}"
            puts "CANVAS CLIENT: #{@canvas_client}"
            
            
            if @google_client
                @drive = @google_client.discovered_api('drive', 'v2')
            end
            
        end
        
        def create_folder(name)
            
            new_folder = @drive.files.insert.request_schema.new({
                            'title'=> "#{name}",
                            'mimeType' => 'application/vnd.google-apps.folder'
                            })

            result = @google_client.execute(
                :api_method => @drive.files.insert,
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
            result = @google_client.execute(:api_method => @drive.files.get, :parameters => { 'fileId' => id})

            if result.status == 200
                puts "FILE INFO RETRIEVAL SEEMED TO GO OKAY"
                return result.data
            else
                puts "SOMETHING WENT WRONG WHEN RETRIEVING FILE INFO"
                return -1
            end
        end

        def copy_file(fileid, parentid, title)
            copy_of_file = @drive.files.copy.request_schema.new({
                'title' => title,
                'parents' => [{ 'id' =>parentid}]
                })

            result = @google_client.execute(
                :api_method => @drive.files.copy,
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
            about_result = @google_client.execute(:api_method => @drive.about.get)
            if about_result.status == 200
                puts "ACCESSING DRIVE OF USER: #{about_result.data.name}"
            else
                puts "SOMETHING WENT WRONG ACCESSING USER INFO"
            end
        end

        def get_permissions_for_file(id)
            perms_result = @google_client.execute(:api_method=>@drive.permissions.list, :parameters => {'fileId' => id})
            if perms_result.status == 200
                puts "PERMISSIONS LISTING SEEMED TO WORK OKAY"
            else
                puts "SOMETHING WENT WRONG WITH PERMISSION LISTING"
            end
        end

        def list_all_files_on_drive
            api_result = @google_client.execute(:api_method => @drive.files.list, :parameters => {})
            if api_result.status == 200
                puts "FILE LISTING SEEMED TO WORK OKAY"
            else
                puts "SOMETHING WENT WRONG WITH FILE LISTING"
            end
        end

        def touch_file(id) 
            touch_result = @google_client.execute(
                :api_method => @drive.files.touch,
                :parameters =>{'fileId' => id})
            if touch_result.status == 200
                puts "TOUCHING FILE SEEMED TO WORK OKAY"
            else
                puts "SOMETHING WENT WRONG TOUCHING FILE"
                puts touch_result.data
            end
        end

        def send_file_to_trash(id)
            trash_result = @google_client.execute(
                :api_method => @drive.files.trash,
                :parameters => {'fileId' => id})
            if trash_result.status == 200
                puts "TRASHING FILE SEEMED TO WORK OKAY"
            else
                puts "SOMETHING WENT WRONG TRASHING FILE"
            end
        end

        def recover_file_from_trash(id)
            untrash_result = @google_client.execute(
                :api_method => @drive.files.untrash,
                :parameters => {'fileId' => id})

            if untrash_result.status == 200
                puts "UNTRASHING FILE SEEMED TO WORK OKAY"
            else
                puts "SOMETHING WENT WRONG UNTRASHING FILE"
            end
        end

        def list_parents_of_file(id)
            list_parents_result = @google_client.execute(
                :api_method => @drive.parents.list,
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
            new_permission = @drive.permissions.insert.request_schema.new({
                'value' => 'email',
                'type' => 'user',
                'role' => 'writer'
            })

            result = @google_client.execute(
                :api_method => @drive.permissions.insert,
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

        def share_file(lti_user_id, from_lti_user_id, fileid)
            #Get id of user we're sharing to -> should be in result["id"]
            #Get user from id
            lti_user = User.find_by(id: lti_user_id)
            if lti_user
                #if user exists...get email
               if lti_user.email 
                    #if email exists, do share
                   share_file_on_drive(fileid, lti_user.email)
                else
                    #if email does not exist, send message via conversation
                   puts "LTI USER #{lti_user_id} HAS NOT LOGGED INTO LTI YET...ADDING REQUEST TO TABLE...SENDING MESSAGE"
                   ShareRequests.create(creator: from_lti_user_id, for: lti_user_id, file_id: fileid)
                    @canvas_client.start_conversation(lti_user.canvas_user_id, 'One or more files have been shared with you on Google Drive. Please log in to MU Labs to view.')

                end
            else
                 #if user does not exist, add to ShareRequests table
                #TODO: rethink ShareRequests table, currently does not make sense. If there is no User for lti_user_id, then it doesn't
                #make sense to record it here.
                puts "LTI USER: #{lti_user_id} DOES NOT EXIST...ADDING REQUEST TO TABLE...SENDING MESSAGE."
                ShareRequests.create(creator: from_lti_user_id, for: lti_user_id, file_id: fileid)
                @canvas_client.start_conversation(lti_user.canvas_user_id, 'One or more files have been shared with you on Google Drive. Please log in to MU Labs to view.')
            end
        end
        
        def delete_file(fileid)
            result = @google_client.execute(:api_method => @drive.files.delete, :parameters => { 'fileId' => fileid})
            if result.status != 200 || result.status != 204
                puts "ERROR DELETING FILE WITH ID: #{fileid}"
                puts "RESULT STATUS: #{result.status}"
                puts result.body.inspect
            else
                puts "(#{result.status}) SUCCESSFUL DELETION!"
                puts result.body.inspect
            end
        end
        
        def list_children(folderid)
            result = @google_client.execute(:api_method => @drive.children.list, :parameters => { 'folderId' => folderid})
            if result.status != 200
                puts "ERROR LISTING CHILDREN OF: #{folderid}"
                puts "RESULT STATUS: #{result.status}"
                puts result.body.inspect
                return []
            else
                puts "(#{result.status}) SUCCESSFUL LISTING"
                puts result.body.inspect
                return result.data
            end
        end
    end
end