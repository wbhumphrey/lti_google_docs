require_dependency "lti_google_docs/application_controller"
require_dependency "../../lib/lti_google_docs/GoogleDriveClient"

module LtiGoogleDocs::Api::V2
    class InstancesController < LtiGoogleDocs::ApplicationController
        def index
            api_token = request.headers["HTTP_LTI_API_TOKEN"]
            if !api_token
                puts 'Missing API token in LTI_API_TOKEN header'
                render json: { error: 'Missing API token in LTI_API_TOKEN header'}.to_json, status: :bad_request
                return
            end
            
            u = User.find_by(api_token: api_token)
            if !u
                puts "USER NOT FOUND FOR GIVEN API TOKEN: #{api_token}"
                render json: {error: 'Invalid API token'}.to_json, status: :bad_request
                return
            end
            
            #TODO: check user variable to see if api_token has expired
            
            instances = LabInstance.all
            
            render json: instances.to_json
        end
        
        def create
            api_token = request.headers["HTTP_LTI_API_TOKEN"]
            if !api_token
                puts 'Missing API token in LTI_API_TOKEN header'
                render json: { error: 'Missing API token in LTI_API_TOKEN header'}.to_json, status: :bad_request
                return
            end
            
            u = User.find_by(api_token: api_token)
            if !u
                puts "USER NOT FOUND FOR GIVEN API TOKEN: #{api_token}"
                render json: {error: 'Invalid API token'}.to_json, status: :bad_request
                return
            end

            #TODO: check user variable to see if api_token has expired
            
            lab_id = params[:lab_id]
            result = {}
            
            if !lab_id
                puts "NO IDEA HOW WE GOT HERE"
                render json: {error: "Missing lab_id parameter."}.to_json, status: :bad_request
                return
            end

            lab = Lab.find_by(id: lab_id)
            puts lab.inspect
            if !lab
                puts "NO LAB FOUND FOR ID: #{lab_id}"
                render json: result
                return
            end

            course = Course.find_by(id: lab.course_id)
            if !course
                puts "ERROR FINDING COURSE WITH ID: #{lab.course_id}"
                render json: {error: 'No course could be found for lab'}.to_json, status: :bad_request
                return
            end

            client = Client.find_by(id: course.client_id)
            if !client
                puts "ERROR FINDING CLIENT WITH ID: #{course.client_id}"
                render json: {error: 'No client could be found for course'}.to_json, status: :bad_request
                return
            end

            #retrieve students enrolled in course
            puts "RETRIEVING STUDENTS ENROLLED IN COURSE"
            canvas_client = new_canvas_client(client)
            canvas_client.access_token = u.canvas_access_token
            lti_course_id = lab.course_id
            lti_course = Course.find_by(id: lti_course_id)
            students = canvas_client.list_students_in_course(lti_course.canvas_course_id)

            puts "STUDENTS RETRIEVED, INSPECTING..."
            puts students.inspect

            #retrieve lab instances
            instances = LabInstance.where(labid: lab_id)

            # are there existing lab instances?
            if !instances.blank?
                render json: {students: student, instances: instances}.to_json
                return
            end

            # are there any students?
            if students.blank?
                # no students enrolled in course
                puts "NO STUDENTS ENROLLED IN COURSE!"
                render json: [].to_json
                return
            end
            
            #there are no lab instances associated with this lab, ergo we need to create them
            #possibility that there are students enrolled in the course
            
            if !students.kind_of?(Array)
                
                if students["status"] == "unauthenticated"
                    render json: {error: "Cannot complete request. Unable to authenticate user with Canvas."}.to_json, status: :bad_request
                    return
                end
                
                render json: {error: "Unidentified error when retrieving students from Canvas."}.to_json, status: :internal_server_error
                return
            end
            
            
            if students.kind_of?(Array)
                #we have students, so we know we'll need to be creating some files on their drive account

                #validate our access token from google
                validate_google_access_token(u)

                #get id of file to copy, associated with lab
                id_of_file_to_copy = lab.folderId

                #get files from folder to be copied
                drive = new_drive(client)
                files_from_folder_to_be_copied = drive.list_children(id_of_file_to_copy)

                # are there files in the shared folder?
                if files_from_folder_to_be_copied.blank?
                    puts "NO FILES WERE FOUND IN THE SPECIFIED FOLDER: #{lab.folderId}"
                    render json: [].to_json
                    return
                end
                
                #there are files within the folder
                puts "NUMBER OF STUDENTS: #{students.size}"
                puts "NUMBER OF FILES: #{files_from_folder_to_be_copied.items.size}"

                ###we either need to do for every student, or for every group... ###
                
                if lab.participation != 'Individual' && lab.participation != 'Group'
                    render json: {error: 'Participation Not Supported: #{lab.participation}'}.to_json, status: :bad_request
                    return
                end
                
                if lab.participation == 'Group'
                    # get groups from canvas
                    puts "RETRIEVING CANVAS GROUPS FROM CANVAS COURSE: #{lti_course.canvas_course_id}"
                    canvas_groups = JSON.parse(canvas_client.list_groups_in_course(lti_course.canvas_course_id))
                    puts canvas_groups
                    puts "TYPE OF CLASS FOR canvas_groups: #{canvas_groups.class}"
                    # FOR EVERY CANVAS GROUP
                    canvas_groups.each do |canvas_group|
                        puts "- FOUND GROUP: #{canvas_group['name']}"
                        # create lti_group 
                        puts "- CREATING LTI GROUP!"
                        lti_group = Group.new(lti_course_id: lti_course_id,
                                                lti_lab_id: lab_id,
                                                canvas_group_id: canvas_group['id'],
                                                name: "#{lab.title} #{canvas_group['name']}")

                        title = "#{canvas_group['name']} - #{lab.title}"
                        puts "- CREATING NEW FOLDER ON DRIVE: #{title}"
                        id_of_new_folder = drive.create_folder(title)
                        
                        newly_copied_file_ids = []
                        puts "- COPYING FILES FROM TEMPLATE INTO NEWLY CREATED FOLDER ON DRIVE"
                        # share copies of all files in folder
                        files_from_folder_to_be_copied.items.each do |file|
                            file_data = drive.get_file_info(file.id)
                            file_title = file_data.title

                            puts "- - - COPYING #{file_title}"
                            copy_file_result = drive.copy_file(file.id, id_of_new_folder, file_title);
                            id_of_new_file = copy_file_result["id"]

                            ### PUT IDs OF COPIED FILES IN ARRAY SO WE CAN SHARE THEM LATER ###
                            newly_copied_file_ids.push(id_of_new_file)
                        end
            
                        ### FOR EVERY MEMBER IN CANVAS GROUP
                        puts "- RETRIEVING GROUP MEMBERS!"
                        canvas_group_members = JSON.parse(canvas_client.list_members_in_group(canvas_group['id']))
                        canvas_group_members.each do |canvas_group_member|
                            puts "- - FOUND GROUP MEMBER: #{canvas_group_member['user_id']}"
                            # create group membership model
                            group_member_lti_user = User.find_by(canvas_user_id: canvas_group_member['user_id'])
                            if !group_member_lti_user
                                # no User was found for that canvas_user_id ...this person has not logged in yet?
                                puts "- - NO EXISTING USER FOUND FOR CANVAS USER: #{canvas_group_member['user_id']}...CREATING ONE!"
                                group_member_lti_user = User.create(canvas_user_id: canvas_group_member['user_id'])
                                
                            end
                
            
                            puts "- - CREATING LTI GroupMember!"
                            lti_group_member = GroupMember.create(lti_user_id: group_member_lti_user.id,
                                                                 lti_group_id: lti_group.id,
                                                                 canvas_user_id: canvas_group_member['user_id'])

                            puts "- - SHARING NEWLY CREATED FOLDER ON DRIVE"
                            # share copy of folder
                            #                to                         , from              , folder
                            drive.share_file(group_member_lti_user.id, u.id, id_of_new_folder)
                            newly_copied_file_ids.each do |id_of_new_file|                 
            
                                puts "- - - SHARING COPIED FILE WITH GROUP MEMBER"
                                drive.share_file(group_member_lti_user.id, u.id, id_of_new_file)
                            end
                        end

                        lti_lab_instance = LabInstance.create(labid: lab.id, studentid: lti_group.id, fileid: id_of_new_folder)
                        lti_group.lti_lab_instance = lti_lab_instance
                        lti_group.save
                        # 
                    end
                
                    result = {students: students, lab_instances: LabInstance.where(labid: lab.id)}
                    
                elsif lab.participation == 'Individual'

                    #for every student enrolled in the course...
                    students.each do |student|
                        title = "#{student['name']} - #{lab.title}"

                        #create new folder for student
                        id_of_new_folder = drive.create_folder(title)
                        #share file (or try to)
                        drive.share_file(student['id'], u.canvas_user_id, id_of_new_folder)

                        #now that the folder is created, lets populate it with copied files

                        #for every file we need to copy
                        files_from_folder_to_be_copied.items.each do |file|
                            #get the meta data of the file
                            file_data = drive.get_file_info(file.id)
                            #grab the title from the meta data
                            file_title = file_data.title
                            #actually copy the file
                            drive.copy_file(file.id, id_of_new_folder, file_title)

                            
                            lti_student = User.find_by(id: student['id'])
                            #try to share the file with the student
                            drive.share_file(lti_student.id, u.id, file.id)
                        end

                        #now we can create the lab instance
                        lab_instance = LabInstance.create(labid: lab.id, studentid: student['id'], fileid: id_of_new_folder);
                    end 

                    result = {students: students, lab_instances: LabInstance.where(labid: params[:id])}
                end
                
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
    
    
        def new_canvas_client(client)
            cc = LtiGoogleDocs::CanvasClient.new(client.canvas_url)
            cc.client_id = client.canvas_clientid
            cc.client_secret = client.canvas_client_secret
            
            #this needs to be domain_tool_is_running_on:port_tool_is_using/lti_google_docs/register/confirmed2
            cc.redirect_uri = "http://"+get_my_ip_address+":31337/lti_google_docs/register/confirmed2"
            return cc
        end
    
    
        #======= UTILITIES
        def validate_google_access_token(user)
            if is_google_access_token_valid?(user.google_access_token)
                #token is valid
            else
                #token is not valid, we need to refresh it.
                #start by retrieving user credentials for the user of this session
                puts "TOKEN IS INVALID, REFRESHING TOKEN"
                if !user
                    #user does not exist
                    puts "TRYING TO REFRESH GOOGLE ACCESS TOKEN, BUT NO USER IS ASSOCIATED WITH REQUEST"
                else
                    #user exists
                    user.google_access_token = retrieve_access_token(user.refresh)
                    user.save
                    puts "ACCESS TOKEN REFRESHED"
                end
            end
        end
        
        def new_drive(client)
            return @drive_client if @drive_client
            @drive_client = LtiGoogleDocs::GoogleDriveClient.new(:google_client => google_client, :canvas_client => new_canvas_client(client))
            
            return @drive_client
        end
    end
end