require_dependency "lti_google_docs/application_controller"
require_dependency "lti_google_docs/labs_controller"



module LtiGoogleDocs
  class LaunchController < ApplicationController

    #The initial loading point for our LTI
    def index
        render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
    end
      
    #The initial page will load a window up directed to this action if
    # 1) No existing access token is present and no refresh token is present
    # 2) No existing access token is present, and retrieving an access token from refresh token causes an error.
    # Item 2 can happen if User specifically revokes access to App via https://security.google.com/settings/u/0/security/permissions?pli=1
    def auth
        
        puts "params from auth: #{params}"
        ps = {};
        puts "AUTHING! - Google redirect uri: #{google_client.authorization.redirect_uri}"
        ps[:redirect_uri] = google_client.authorization.redirect_uri
        ps[:client_id] = google_client.authorization.client_id
        ps[:scope] = "https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/userinfo.email"
        ps[:immediate] = false
        ps[:approval_prompt] = 'force'
        ps[:response_type] = 'code'
        ps[:access_type] = 'offline'
        ps[:state] = "canvas_server_address=#{params[:canvas_server_address]},canvas_user_id=#{params[:canvas_user_id]},needs_canvas=#{params[:needs_canvas]}"

        query = ps.to_query
        puts query
        redirect_to "https://accounts.google.com/o/oauth2/auth?#{query}"
    end
        
    def factory
    end
  end
end
