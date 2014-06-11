require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs
  class LabsController < ApplicationController
  
      #GET /labs
      def index
      end
      
      #GET /labs/new
      def new
      end
      
      #POST /labs
      def create
          title = params[:title]
          folderName = params[:folderName]
          google_drive_folder_id = params[:folderId]
          participation = params[:participation]
          
          lab = Lab.create(title: title, folderName: folderName, folderId: google_drive_folder_id, participation: participation);
          
          
          render text: "lab created!"
      end
      
      #GET /labs/:id
      def show
      end
      
      #GET /labs/:id/edit
      def edit
      end
          
      #PATCH/PUT /labs/:id
      def update
      end
      
      #DELETE /labs/:id
      def destroy
      end
  
  end
end
