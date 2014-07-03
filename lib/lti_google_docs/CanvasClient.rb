module LtiGoogleDocs
    class CanvasClient

        def initialize(canvas_url)
            @canvas_url = canvas_url
            @auth_uri = "#{canvas_url}/login/oauth2/token"
        end

        def client_id
            return @client_id
        end

        def client_id=(id)
            @client_id=id
        end


        def redirect_uri
            return @redirect_uri
        end

        def redirect_uri=(uri)
            @redirect_uri=uri
        end


        def client_secret
            return @client_secret
        end

        def client_secret=(secret)
            @client_secret = secret
        end

        def auth_code
            return @code
        end

        def auth_code=(code)
            @code = code
        end

        def access_token
            return @access_token
        end
        
        def access_token=(token)
            @access_token = token
        end

        def request_access_token!
            uri = URI.parse(@auth_uri)
            response = Net::HTTP.post_form(uri, {"client_id"=>@client_id, "redirect_uri"=>@redirect_uri, "client_secret"=>@client_secret, "code"=>@code})
            @access_token = JSON.parse(response.body)['access_token']
        end

        def list_courses
            uri = URI.parse("#{@canvas_url}/api/v1/courses?access_token=#{@access_token}")
            puts "LISTING COURSES URI: #{uri}"
            response = Net::HTTP.get_response(uri)
            JSON.parse(response.body)
        end

        def list_students_in_course(course_id)
            uri = URI.parse("#{@canvas_url}/api/v1/courses/#{course_id}/users?access_token=#{@access_token}&enrollment_type=student")
            
            puts "LISTING STUDENTS URI: #{uri}"
            response = Net::HTTP.get_response(uri)
            JSON.parse(response.body)
        end

        def add_tool_to_course(course, tool_name, tool_url)
            uri = URI.parse("#{@canvas_url}/api/v1/courses/#{course}/external_tools")
            http = Net::HTTP.new(uri.host, uri.port)
            request = Net::HTTP::Post.new(uri.request_uri)

            request["Authorization"] = "Bearer #{@access_token}"

            puts request["Authorization"]

            request.set_form_data({"name"=>tool_name, "consumer_key"=>"test", "shared_secret"=>"secret", "url"=>tool_url,"privacy_level"=>"public"})

            response = http.request(request);


    #        response = Net::HTTP.post_form(uri, {"access_token"=>"#{@access_token}","name"=>tool_name, "consumer_key"=>"test", "shared_secret"=>"secret", "url"=>tool_url,"privacy_level"=>"public"});

            puts "ADDED TOOL"
            puts response.body
        end
        
        def start_conversation(to, message)
            uri = URI.parse("#{@canvas_url}/api/v1/conversations")
            http = Net::HTTP.new(uri.host, uri.port)
            
            request = Net::HTTP::Post.new(uri.request_uri)
            request["Authorization"] = "Bearer #{@access_token}"
            
            request.set_form_data({"recipients"=>"#{to}", "subject" => "Attention ASDF GHJKL!", "body"=>message, "group_conversation"=>false, "attachment_ids"=>[], "scope"=>'unread'})
            
            puts "SENDING CONVERSATION START REQUEST TO RECIPIENTS: #{to}"
            response = http.request(request)
            puts response.body
        end
    end
end