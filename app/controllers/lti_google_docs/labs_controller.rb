require_dependency "lti_google_docs/application_controller"
require '../../lib/lti_google_docs/Configuration'
require 'yaml'

module LtiGoogleDocs
  class LabsController < ApplicationController
  
      #GET /labs
      def index
          render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
      end

      def start
          render text: "Not Implemented Yet."
      end
      
      def show
       render text: "Not Implemented Yet."
      end
      
      def all
          render text: "Not Implemented Yet."
      end
      
      #POST /labs/:id/view
      def view
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

  end
end
end
