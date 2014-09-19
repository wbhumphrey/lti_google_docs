require_dependency "lti_google_docs/application_controller"
require_dependency "lti_google_docs/labs_controller"



module LtiGoogleDocs
  class LaunchController < ApplicationController

    #The initial loading point for our LTI
    def index
        puts "INSIDE INDEX!"

        #NO NEED TO SET session[:userid] here, IT'S ALREADY DONE IN ApplicationController
        
        render template: 'lti_google_docs/launch/error', tp: tool_provider if tool_provider.lti_msg
    end
      
    #The initial page will load a window up directed to this action if
    # 1) No existing access token is present and no refresh token is present
    # 2) No existing access token is present, and retrieving an access token from refresh token causes an error.
    # Item 2 can happen if User specifically revokes access to App via https://security.google.com/settings/u/0/security/permissions?pli=1
    def auth
        
        puts "params from auth: #{params}"
        puts "SESSION IN AUTH: #{session[:userid]}"
        ps = {};
      
        puts "AUTHING! - Google redirect uri: #{google_client.authorization.redirect_uri}"
        ps[:redirect_uri] = google_client.authorization.redirect_uri
        ps[:client_id] = google_client.authorization.client_id
        ps[:scope] = "https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/userinfo.email"
        ps[:immediate] = false
        ps[:approval_prompt] = 'force'
        ps[:response_type] = 'code'
        ps[:access_type] = 'offline'
        ps[:state] = '0xDEADBEEF'

        query = ps.to_query
        puts query
        redirect_to "https://accounts.google.com/o/oauth2/auth?#{query}"
    end

    def hello
        
#        puts "TOKEN: #{session[:google_access_token]}"
#        client = Google::APIClient.new
#        client.authorization.client_id = @@CLIENT_ID
#        client.authorization.client_secret = @@CLIENT_SECRET
        google_client.authorization.access_token = session[:google_access_token]
#        client.authorization.access_token = session[:google_access_token]
#        client.authorization.scope = @@SCOPES[0]
        drive = google_client.discovered_api('drive', 'v2')
        api_result = google_client.execute(
            :api_method => drive.files.list,
            :parameters => {});
        
        #puts api_result.inspect
        result = Array.new
        if api_result.status == 200
            files = api_result.data    
            result.concat(files.items)
        else
            puts "DIDN'T WORK SO REFRESHING ACCESS TOKEN"
            puts "LOOKING FOR USER WITH ID: #{session[:userid]}"
            
            
            refreshToken = User.find_by(userid: session[:userid]).refresh
            accessToken = retrieve_access_token(refreshToken)
            puts "RETRIEVED TOKEN: #{accessToken} ... PUTTING IN SESSION"
            session[:google_access_token] = accessToken
            
            google_client.authorization.access_token = accessToken
            drive = google_client.discovered_api('drive', 'v2')
            api_result = google_client.execute(:api_method => drive.files.list,
                                        :parameters => {});
            puts "RESULT FOR TRY 2: #{api_result.status}"
            if api_result.status == 200
                files = api_result.data
                result.concat(files.items)
            end
        end    
        
        render json: result
    end

        
        
    def factory
    end
        
    def files
        hello
    end
  end
end
