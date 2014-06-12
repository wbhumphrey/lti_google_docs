require_dependency "lti_google_docs/application_controller"
require 'yaml'
module LtiGoogleDocs
  
  class Configuration
    def initialize
        puts "GETTING CONFIGURATION!"
        config = YAML.load_file(File.join(__dir__, '../../../', 'config.yml'))
        puts config.inspect
        @client_id = config['Google_Credentials']['client_id']
        @client_secret = config['Google_Credentials']['client_secret']
        @redirect_uri = config['Google_Credentials']['redirect_uri']
        @scopes = ["#{config['Google_Credentials']['scopes']}"]
    end
    
    def client_id
        @client_id
    end
    
    def client_secret
        @client_secret
    end
    
    def redirect_uri
        @redirect_uri
    end
    
    def scopes
        @scopes
    end
  end


  class LabsController < ApplicationController
  
      #GET /labs
      def index
          obj = YAML.load_file(File.join(__dir__,'../../../', 'config.yml'))
          puts obj.inspect
          
          render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
      end

      def start
          puts request.inspect
          
          if tool_provider.lti_msg
              render template: 'lti_google_docs/launch/error', tp: tool_provider
          else
              render :index
          end
      end
      
      
      def all
          puts request.inspect
          
            labs = Lab.all
          render json: labs
      end
      
      #POST /labs/new
      def create
          puts "INSIDE CREATE"
          puts params.inspect
          
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
          puts params.inspect
      
          lab_id = params[:id]
          puts "DELETING LAB WITH ID: #{lab_id}"
          
          lab = Lab.find_by(id: lab_id)
          lab.destroy
          
          
          render text: "ok"
      end
  end
end
