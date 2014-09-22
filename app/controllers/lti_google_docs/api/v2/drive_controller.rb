require_dependency "lti_google_docs/application_controller"

module LtiGoogleDocs::Api::V2
    class DriveController < LtiGoogleDocs::ApplicationController
        
        def index
            api_token = request.headers["HTTP_LTI_API_TOKEN"]
            if !api_token
                puts 'Missing API token in LTI_API_TOKEN header'
                render json: { error: 'Missing API token in LTI_API_TOKEN header'}.to_json, status: :bad_request
                return
            end
            
            u = User.find_by(api_token: api_token)
            if !u
                puts 
                render json: {error: 'Invalid API token'}.to_json, status: :bad_request
                return
            end
            
            if !u.google_access_token
                render json: {error: 'Missing google_access_token'}.to_json, status: :bad_request
            end
            
            puts "RETRIEVING FILE LIST FROM GOOGLE DRIVE"
            #here we need to retrieve the drive files associated with the currently logged in user.
            google_client.authorization.access_token = u.google_access_token
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
                refreshToken = u.refresh
                accessToken = retrieve_access_token(refreshToken)
                puts "RETRIEVED ACCESS TOKEN: #{accessToken} ... PUTTING IN Users TABLE"
                u.google_access_token = access_token
                u.save

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