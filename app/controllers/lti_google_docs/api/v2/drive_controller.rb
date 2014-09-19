require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs::Api::V2
    class DriveController < LtiGoogleDocs::ApplicationController
        def index
            puts "RETRIEVING FILE LIST FROM GOOGLE DRIVE"
            
            #here we need to retrieve the drive files associated with the currently logged in user.
            google_client.authorization.access_token = session[:google_access_token]
            drive = google_client.discovered_api('drive', 'v2')
            api_result = google_client.execute(
                :api_method => drive.files.list,
                :parameters => {});
            
            result = Array.new
            if api_result.status == 200
                puts "RETRIEVAL SUCCEEDED"
                files = api_result.data
                result.concat(files.items)
            else
                puts "RETRIEVAL FAILED, REFRESHING ACCESS TOKEN"
                refreshToken = User.find_by(userid: session[:userid]).refresh
                accessToken = retrieve_access_token(refreshToken)
                puts "RETRIEVED ACCESS TOKEN: #{accessToken} ... PUTTING IN SESSION"
                session[:google_access_token] = accessToken
                
                google_client.authorization.access_token = accessToken
                drive = google_client.discovered_api('drive', 'v2')
                puts "TRYING AGAIN TO RETRIEVE LIST OF FILES"
                api_result = google_client.execute(
                    :api_method => drive.files.list,
                    :parameters => {});
                if api_result.status == 200
                    puts "RETRIEVAL 2 SUCCEEDED!"
                    files = api_result.data
                    result.concat(files.items)
                else
                    puts "RETRIEVAL 2 FAILED!"
                    puts api_result.inspect
                end
            end
            
            render json: result
            return
        end
    end
end