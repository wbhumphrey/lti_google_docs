require_dependency "lti_google_docs/application_controller"
require '../../lib/lti_google_docs/Configuration'
require 'yaml'
module LtiGoogleDocs
  class LabsController < ApplicationController
  
      #GET /labs
      def index
          puts "INSIDE LABS INDEX"
#          obj = YAML.load_file(File.join(__dir__,'../../../', 'config.yml'))
#          puts obj.inspect
          @access_token = session[:google_access_token]
          @canvas_access_token = session[:canvas_access_token]
          render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
          
      end

      def start
          puts "INSIDE LAB START!"
#          puts request.inspect
          
          puts params.inspect
          session[:userid] = params[:user_id]
          session[:current_course_id] = params["custom_canvas_course_id"]
          
          @access_token = session[:google_access_token]
          @canvas_access_token = session[:canvas_access_token]
          
          
          if tool_provider.lti_msg
              render template: 'lti_google_docs/launch/error', tp: tool_provider
          else
              render :index
          end
      end
      
      
      def all
#          puts request.inspect
          puts "CANVAS ACCESS TOKEN FROM SESSION: #{session[:canvas_access_token]}"
          puts "CANVAS ACCESS TOKEN FROM CLIENT: #{canvas_client.access_token}"
          puts "MY USER ID FROM SESSION: #{session[:userid]}"
          canvas_client.access_token = session[:canvas_access_token]
          canvas_client.start_conversation(session[:userid], "Testing Message")
            labs = Lab.all
          render json: labs
      end
      
      #POST /labs/new
      def create
          puts "INSIDE CREATE"
#          puts params.inspect
          
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
      
          puts "INSIDE REMOVE!"
#          puts params.inspect
      
          lab_id = params[:id]
          puts "DELETING LAB WITH ID: #{lab_id}"
          
          lab = Lab.find_by(id: lab_id)
        if(!lab)
        else
            
            
            lab_instances = LabInstance.where(labid: lab_id)
            
            if !lab_instances.blank?
                # delete folder on google drive
                
                if is_google_access_token_valid?(session[:google_access_token])
                    puts "GOOGLE ACCESS TOKEN VALID IN LAB REMOVE"
                else
                    u = User.find_by(id: session[:userid])
                    if !u
                        puts "USER DOES NOT EXIST!"
                    else
                        puts "REFRESHING ACCESS TOKEN"
                        retrieve_access_token(u.refresh)
                    end
                end
                    
                drive = google_client.discovered_api('drive', 'v2')
                
                
                
                lab_instances.each do |li|
                    file_to_delete_from_drive = li.fileid
                    puts "ID OF FILE TO DELETE: #{li.fileid}"
                    
                    result = google_client.execute(:api_method => drive.files.delete,
                                                :parameters => {'fileId' => file_to_delete_from_drive})
                    
                    if result.status != 204
                        puts "ERROR DELETING FILE WITH ID: #{li.fileid}"
                        puts "RESULT STATUS #{result.status}"
                        puts result.body.inspect
                    else
                        puts "SUCCESSFUL DELETION!"
                    end
                end
            end
            
            #destroy lab instances
            LabInstance.destroy_all(labid: lab_id)
        end
          #destroy labs
            lab.destroy
          render text: "ok"
      end
  end
end
