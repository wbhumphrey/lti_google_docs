require_dependency "lti_google_docs/application_controller"
require_dependency "../../lib/lti_google_docs/GoogleDriveClient"

require 'json'

module LtiGoogleDocs::Api::V2
    class LabsController < LtiGoogleDocs::ApplicationController
        
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

            
            
            
            labs = Lab.all
            render json: labs
        end
        
        # POST as an LTI from Canvas
        def create
            # get custom_canvas_course_id from params
            custom_canvas_user_id = params["custom_canvas_user_id"]
            
            # FOR THIS CONTROLLER, WE NEED BOTH A CANVAS ACCESS TOKEN *AND* A GOOGLE ACCESS TOKEN
            @canvas_user_id = params[:custom_canvas_user_id]
            @canvas_server_address = params[:custom_canvas_api_domain]
            # get User entry if it exists
            
            if !@canvas_user_id || @canvas_user_id == nil
                render text: "No canvas user id was sent. Maybe the person who installed the LTI did not specify public access?"
                return
            end
            
            lti_user = User.find_by(canvas_user_id: custom_canvas_user_id)
            
            if !lti_user
                # tell the client we need both the google access token and the canvas token
                @need_google_token = true
                @need_canvas_token = true
            else 
                
                if !lti_user.refresh || lti_user.refresh == "" || lti_user.refresh == nil
                    @need_google_token = true
                    @need_canvas_token = true
                    lti_client = Client.find_by(client_id: params[:oauth_consumer_key])
                    @canvas_clientid = lti_client.canvas_clientid
                    render "retrieve_resource_tokens"
                    return
                end
                    
                validate_google_access_token(lti_user)
                @need_google_token = !lti_user.google_access_token
                @need_canvas_token = !lti_user.canvas_access_token
            end
        
            if @need_google_token || @need_canvas_token
                render "retrieve_resource_tokens"
                return
            end
            
            custom_canvas_course_id = params[:custom_canvas_course_id]
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
            
            
            #TODO: GENERATE API TOKEN, PUT IN USERS TABLE WITH THIS USER ID
            # @api_token = ... ?
            @api_token = generateToken
            lti_user.api_token = @api_token
            lti_user.save
            render "lab_creator"
        end
        
        # POST - ajax request from lab_creator
        def new
            puts "INSIDE NEW"
            
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

            if request.post?
                if !params["course_id"]
                    puts "NO COURSE ID FOUND, FAILING GRACEFULLY"
                    render json: {error: "No course id, no new lab."}.to_json, status: :bad_request
                    return;
                end

                existing_lab = Lab.find_by(course_id: params["course_id"], title: params["title"])

                if !existing_lab
                    title = params[:title]
                    folderName = params[:folderName]
                    google_drive_folder_id = params[:folderId]
                    participation = params[:participation]

                    lab = Lab.create(title: title,
                                    folderName: folderName,
                                    folderId: google_drive_folder_id,
                                    participation: participation,
                                    course_id: params["course_id"])
                    
                    course_id = params["course_id"]
                    canvas_course = Course.find_by(id: course_id)
                    
                    client_id = canvas_course.client_id
                    canvas_course_id = canvas_course.canvas_course_id
                    client = Client.find_by(id: client_id)
                    key = client.client_id
                    secret = client.client_secret
                    canvas_client = new_canvas_client(client)
                    canvas_client.access_token = u.canvas_access_token
                    host = request.headers['host'].split(':')[0]
                    
                    url = "https://#{host}:#{request.port}/lti_google_docs/api/v2/labs/#{lab.id}/launch"
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
                        
                        tool_json_result = canvas_client.publish_tool_to_course_module(canvas_course_id, canvas_course.canvas_module_id, operation_result["id"])
                        tool_result = JSON.parse(tool_json_result)
                        if !tool_result["errors"]
                            puts "PUBLISHED LAB IN MODULE!"
                        else
                            puts "THERE WERE ERRORS PUBLISHING LAB IN OUR MODULE"
                        end
                        
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

            lab_id = params["id"]
            
            if !lab_id
                puts "HOW IN GODS GREEN EARTH DID WE GET HERE?"
            else
                lab = Lab.find_by(id: lab_id)
                
                if lab
                    puts "DESTROYING LAB"
                    lab.destroy
                    
                    #also destroy any associated tools
                    puts "RETRIEVING ANY LINGERING LTIs IN CANVAS"
                    tool = CanvasTools.find_by(labid: lab_id)
                    
                    if tool
                        course = Course.find_by(id: lab.course_id)
                        if !course
                            tool.destroy
                            render json: {}, status: :no_content
                            return
                        end
                        
                        client = Client.find_by(id: course.client_id)
                        if !client
                            tool.destroy
                            render json: {}, status: :no_content
                            return
                        end
                        
                        
                        canvas_client = new_canvas_client(client)
                        canvas_client.access_token = u.canvas_access_token
                        #remove tool from canvas
                        
                        
                        puts "REMOVING LTI FROM CANVAS"
                        canvas_client.remove_tool_from_course(course.canvas_course_id, tool.canvas_tool_id)

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
        
        # POST as an LTI from Canvas
        def launch
            puts params.inspect

            
            @lab_id = params[:lab_id]
            student_id = params[:custom_canvas_user_id]
            
            # sanity check, if no lab @ lab_id exists, OR params[:lab_id] isn't present, return error code
            
            # sanity check, if no user @ custom_canvas_user_id exists OR params[:custom_canvas_user_id] is not present, return error code
            
            
            @canvas_user_id = params[:custom_canvas_user_id]
            @canvas_server_address = params[:custom_canvas_api_domain]
            # get User entry if it exists
            
            if !@canvas_user_id
                render text: "No canvas user id was sent. Maybe the person who installed the LTI did not specify public access?"
                return
            end
            
            
            u = User.find_by(canvas_user_id: params[:custom_canvas_user_id])
            
            if !u
                # tell the client we need both the google access token and the canvas token
                @need_google_token = true
                @need_canvas_token = false
                
                # we check for designer here, because student's shouldn't be doing anything with canvas access tokens.
                if !tool_provider.student?
                    @need_canvas_token = true
                end
            else 
                validate_google_access_token(u)
                @need_google_token = !u.google_access_token
                @need_canvas_token = false
                
                # we check for designer here, because student's shouldn't be doing anything with canvas access tokens.
                if !tool_provider.student?
                    @need_canvas_token = !u.canvas_access_token
                end
            end
        
            if @need_google_token || @need_canvas_token
                render "retrieve_resource_tokens"
                return;
            else
                puts "CONTINUE WITH LAB AS NORMAL...";
            end
            
            lab = Lab.find_by(id: @lab_id)
            if !lab
                render text: "NO LAB FOUND. LOOK AT OUTPUT TO FIND ERROR!"
                return
            end
            @lab = Lab.find_by(id: @lab_id)
            
            course = Course.find_by(id: lab.course_id)
            client = Client.find_by(id: course.client_id)

            instances = LabInstance.where(labid: @lab_id)
            # if any lab instance with this lab id exists...
            if !instances.blank?
                puts "THERE ARE LAB INSTANCES"
                # if and only if this is a group lab
                if (lab.participation == 'Group')
                    puts "LAB IS A GROUP LAB"
                    # retrieve all the groups for this lab
                    groups = Group.where(lti_lab_id: @lab_id)
                    
                    if !tool_provider.student?
                        render "designer_group_lab"
                        return
                    end
                    
                    
                    #for every group for this lab
                    groups.each do |group|
                        
                        #retrieve a membership entry matching this lab and this canvas user id
                        membership = GroupMember.find_by(lti_group_id: group.id, canvas_user_id: params[:custom_canvas_user_id])
                        
                        # if the membership exists, we have a winner
                        if membership
                            lab_instance = LabInstance.find_by(id: group.lti_lab_instance)
                        end
                        
                        #if not, continue;
                    end
                else
                    puts "LAB IS AN INDIVIDUAL LAB"
                    lab_instance = LabInstance.find_by(labid: @lab_id, studentid: params[:custom_canvas_userid])
                end
                
                # so now we have the proper lab_instance
                puts "NOW WE HAVE THE PROPER LAB INSTANCE"
                
                # if i am not a student
                if !tool_provider.student?
                    puts "REQUEST IS NOT FROM A STUDENT"
                    if lab_instance
                        puts "LAB INSTANCE EXISTS"
                        # validate google token
                        validate_google_access_token(User.find_by(canvas_user_id: student_id))
                        # retrieve shared_folder_id from labinstance
                        shared_folder_id = lab_instance.fileid
                        # retrieve list of files from shared folder
                        drive = new_drive(client)
                        shared_files_json = drive.list_children(shared_folder_id)
                        # generate object via JSON.generate from list of files (as json)
                        # put generated object in cookie with key 'shared_files'
                        cookies["shared_files"] = JSON.generate(shared_files_json)
                        # show 'student_lab'
                        
                        
                        @api_token = generateToken
                        u.api_token = @api_token
                        u.save
                        puts "RENDER VIEW LAB FOR DESIGNERS"
                        render "designer_lab"
                    end
                    #no lab instance?
                    puts "LAB INSTANCE DOES NOT EXIST"
                # if i AM a student
                else
                    puts "REQUEST IS FROM A STUDENT"
                    if lab_instance
                        puts "LAB INSTANCE EXISTS"
                        # validate google token
                        validate_google_access_token(User.find_by(canvas_user_id: student_id))
                        # retrieve shared_folder_id from labinstance
                        shared_folder_id = lab_instance.fileid
                        # retrieve list of files from shared folder
                        drive = new_drive(client)
                        shared_files_json = drive.list_children(shared_folder_id)
                        # generate object via JSON.generate from list of files (as json)
                        # put generated object in cookie with key 'shared_files'
                        cookies["shared_files"] = JSON.generate(shared_files_json)
                        
                        # show 'student_lab' 
                        @api_token = generateToken
                        u.api_token = @api_token
                        u.save
                        render "student_lab"
                    else
                        #no lab instance exists for this student. Was the student enrolled after lab creation?
                        puts "NO LAB INSTANCE EXISTS FOR THE REQUESTER, WERE THEY ENROLLED AFTER THE LAB WAS CREATED?"
                    end
                end
            else
                puts "NO LAB INSTANCES EXIST"
            # if no lab instance exists
                if !tool_provider.student?
                # if I am not a student
                    #show designer_lab_activation
                    puts "REQUESTER IS NOT A STUDENT"
                    @api_token = generateToken
                    u.api_token = @api_token
                    u.save
                    puts "RENDER LAB ACTIVATION PAGE FOR DESIGNERS"
                    render "designer_lab_activation"
                else
                    puts "REQUESTER IS A STUDENT"
                # if I AM a student
                    #show message to notify instructor that they need to login
                    render text: "Please notify your instructor that they need to login before this lab is activated"
                end
            end
        end
    
        # GET from AJAX request
        def groups

            if !params[:id]
                render json: {error: 'No ID present'}, status: :bad_request
                return
            end
    
            groups_dto = []
            lti_groups = Group.where(lti_lab_id: params[:id])
            puts "- FOUND #{lti_groups.size} groups"
            lti_groups.each do |lti_group|
                students_dto = []
                lti_group_members = GroupMember.where(lti_group_id: lti_group.id) 
                puts "- - FOUND #{lti_group_members.size} group members"
                lti_group_members.each do |member|
                    u = User.find_by(member.lti_user_id)
                    if u
                        students_dto.push(u.email)
                    end
                end
                
                lab = Lab.find_by(id: params[:id])
                lab_instance = LabInstance.find_by(labid: lab.id, studentid: lti_group.id)
                groups_dto.push({students: students_dto, link: lab_instance.fileid})
            end
    
    
            render json: {groups: groups_dto}.to_json
            return
        end
    
        def validate_google_access_token(user)
            if is_google_access_token_valid?(user.google_access_token)
                #token is valid
            else
                #token is not valid, we need to refresh it.
                #start by retrieving user credentials for the user of this session
                puts "TOKEN IS INVALID, REFRESHING TOKEN"

                if !user
                    #user does not exist
                    puts "TRYING TO REFRESH GOOGLE ACCESS TOKEN, BUT NO USER IS ASSOCIATED WITH SESSION"
                else
                    #user exists
                    user.google_access_token = retrieve_access_token(user.refresh)
                    user.save
                    puts "ACCESS TOKEN REFRESHED"
                end
            end
        end
    
    
        def new_canvas_client(client)
            cc = LtiGoogleDocs::CanvasClient.new(client.canvas_url)
            cc.client_id = client.canvas_clientid
            cc.client_secret = client.canvas_client_secret
            
            #this needs to be domain_tool_is_running_on:port_tool_is_using/lti_google_docs/register/confirmed2
            cc.redirect_uri = "http://"+get_my_ip_address+":31337/lti_google_docs/register/confirmed2"
            return cc
        end
    
        def new_drive(client)
            return @drive_client if @drive_client
            @drive_client = LtiGoogleDocs::GoogleDriveClient.new(:google_client => google_client, :canvas_client => new_canvas_client(client))
            
            return @drive_client
        end
    end
end