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
          lab_id = params[:id]
          puts "DELETING LAB WITH ID: #{lab_id}"
          
          lab = Lab.find_by(id: lab_id)
          lab.destroy
 
          render text: "ok"
      end
  end
end
