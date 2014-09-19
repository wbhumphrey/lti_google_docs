require_dependency "lti_google_docs/application_controller"
require '../../lib/lti_google_docs/Configuration'
require 'yaml'

module LtiGoogleDocs
  class LabsController < ApplicationController
  
      #GET /labs
      def index
          puts "INSIDE LABS INDEX"

          @access_token = session[:google_access_token]
          @canvas_access_token = session[:canvas_access_token]
          render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
      end

      def start
          puts "INSIDE LAB START!"

          puts params.inspect
          session[:userid] = params[:custom_canvas_user_id]
          session[:current_course_id] = params["custom_canvas_course_id"]
          
          @access_token = session[:google_access_token]
          @canvas_access_token = session[:canvas_access_token]

          if tool_provider.lti_msg
              render template: 'lti_google_docs/launch/error', tp: tool_provider
          else
              render :index
          end
      end
      
      def show
        "INSIDE LABS SHOW!"
          @access_token = session[:google_access_token]
          @canvas_access_token = session[:canvas_access_token]
          
          labid = params[:id]
          @students_not_logged_in = [];
          if !tool_provider.student?
              # for teachers/designers, we want to
              # 1) Send out pending requests from our userid for labs
              # 1.1) Get requests from us
              requests = ShareRequests.where(creator: session[:userid])
              # 1.2) for every request, get the User associated with :for
              requests.each do |request|
                  student_user_id = request['for'];
                  student = User.find_by(userid: student_user_id);
                  if student
                      #student exists
                      if recipient.email
                          # and has logged in
                          # 1.3) If user has email address, update permission. If not, do nothing
                          drive.share_file_on_drive(request.file_id, recipient.email)

                      else
                          # but has not logged in
                          @students_not_logged_in.push(student);
                      end

                  else
                      #student does not exist
                  end
              end
              
              render 'manage'
          else
              # for students, we want to
              # 1) Get the lab instance for our userid and this lab
              puts "STUDENT SESSION USERID: #{session[:userid]}"
              lab_instance = LabInstance.find_by(studentid: session[:userid])
              if lab_instance
              # 2) Retrieve our folderid in the lab instance
                  folder_id = lab_instance.fileid
              # 3) Get the children of the folder
                  files_in_folder = drive.list_children(folder_id)
              # 4) Show the files
                  puts "FILES FOUND FOR THIS STUDENT: #{files_in_folder.inspect}"
                  cookies['files'] = JSON.generate(files_in_folder);
                  if request.query_parameters[:json]
                      cookies["super secret message"] = "eat more chicken"
                    render json: files_in_folder.to_json;
                    return;
                  end
              else
                  puts "LAB INSTANCE FOR STUDENT NOT FOUND!"
              end
          end
          cookies[:message] = "eat more chicken"
          render "student"
#          render text: "VIEWING LAB: #{params[:id]} WITH REQUEST: #{request.path_parameters.inspect}"
      end
      
      def all
          puts "CANVAS ACCESS TOKEN FROM SESSION: #{session[:canvas_access_token]}"
          puts "CANVAS ACCESS TOKEN FROM CLIENT: #{canvas_client.access_token}"
          puts "MY USER ID FROM SESSION: #{session[:userid]}"
          canvas_client.access_token = session[:canvas_access_token]
          canvas_client.start_conversation(session[:userid], "Testing Message")
            labs = Lab.all
          render json: labs
      end
      
      #POST /labs/:id/view
      def view
          puts "INSIDE LABS VIEW!"
          @access_token = session[:google_access_token]
          @canvas_access_token = session[:canvas_access_token]
          
          if tool_provider.student?
            render 'studentLab'
            return; 
          else if tool_provider.instructor? || tool_provider.admin?
            render 'manageLab'
            return;
          end
          
          render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
      end

      #POST /labs/new
      def create
          puts "INSIDE CREATE"

          existing_lab = Lab.find_by(title: params[:title])
          if !existing_lab
              title = params[:title]
              folderName = params[:folderName]
              google_drive_folder_id = params[:folderId]
              participation = params[:participation]

              lab = Lab.create(title: title, folderName: folderName, folderId: google_drive_folder_id, participation: participation);

              puts "SUCCESS!"
              render text: "lab created!"
          else
              puts "LAB NAMED: #{existing_lab.title} ALREADY EXISTS!"
              render text: "LAB NOT CREATED!";
          end
      end
      
      def remove
          lab_id = params[:id]
          puts "DELETING LAB WITH ID: #{lab_id}"
          
          lab = Lab.find_by(id: lab_id)
          lab.destroy
 
          render text: "ok"
      end

      def drive
        return @drive_client if @drive_client
        
          @drive_client = LtiGoogleDocs::GoogleDriveClient.new(:google_client => google_client, :canvas_client => canvas_client)
        return @drive_client
      end
  end
end
end
