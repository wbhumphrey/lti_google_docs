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
            uri = URI.parse("https://#{@auth_uri}")
            response = Net::HTTP.post_form(uri, {"client_id"=>@client_id, "redirect_uri"=>@redirect_uri, "client_secret"=>@client_secret, "code"=>@code})
            @access_token = JSON.parse(response.body)['access_token']
        end

        def list_courses
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses?access_token=#{@access_token}")
            puts "LISTING COURSES URI: #{uri}"
            response = Net::HTTP.get_response(uri)
            JSON.parse(response.body)
        end

        def list_students_in_course(course_id)
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course_id}/users?access_token=#{@access_token}&enrollment_type=student")
            
            puts "LISTING STUDENTS URI: #{uri}"
            response = Net::HTTP.get_response(uri)
            JSON.parse(response.body)
        end

        def add_tool_to_course(course, tool_name, tool_url)
            add_tool_to_course_with_credentials(course, tool_name, tool_url, "test", "secret")
        end
        
        def add_tool_to_course_with_credentials(course, tool_name, tool_url, consumer_key, shared_secret) 
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course}/external_tools")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.request_uri)

            request["Authorization"] = "Bearer #{@access_token}"

            puts request["Authorization"]

            request.set_form_data({"name"=>tool_name, "consumer_key"=>consumer_key, "shared_secret"=>shared_secret, "url"=>tool_url,"privacy_level"=>"public"})

            response = http.request(request);


    #        response = Net::HTTP.post_form(uri, {"access_token"=>"#{@access_token}","name"=>tool_name, "consumer_key"=>"test", "shared_secret"=>"secret", "url"=>tool_url,"privacy_level"=>"public"});

            puts "ADDED TOOL"
            puts response.body
            return response.body
        end
        
        def add_course_link(course, tool_name, tool_url, consumer_key, shared_secret, link_url, link_caption)
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course}/external_tools")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.request_uri)
            
            request["Authorization"] = "Bearer #{@access_token}"
            puts request["Authorization"]
            
            #course_navigation = {"enabled"=> true, "default"> true, "url" => link_url, "text"=> link_caption, "visibility"=> "admins"}
            request.set_form_data({"name"=> tool_name, "consumer_key"=>consumer_key, "shared_secret"=> shared_secret, "url"=>tool_url, "privacy_level"=>"public", "course_navigation[enabled]"=>true, "course_navigation[default]"=>true, "course_navigation[url]"=>link_url, "course_navigation[text]"=>link_caption, "course_navigation[visibility]"=>"admins"})
            
            response = http.request(request)
            puts "ADDED COURSE LINK"
            puts response.body
            
            if response.body["errors"]
                #problems!
                puts "AN ERROR OCCURRED DURING COURSE LINK ADDING...COURSE LINK NOT ADDED!"
#                puts "OLD TOKEN: #{@access_token}"
#                new_token = request_access_token!
#                puts "NEW TOKEN: #{new_token}"
#                @access_token = new_token
            end
            return response.body
        end
        
        def add_module_to_course(course, name)
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course}/modules")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.request_uri)
            request["Authorization"] = "Bearer #{@access_token}"
            
            request.set_form_data({"module[name]" => name, "module[published]" => true})
            response = http.request(request)
            puts "SENDING REQUEST TO CREATE MODULE"
            puts response.body
            
            return response.body
        end
        
        def add_tool_to_course_module(course, module_id, tool_id, label, tool_url)
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course}/modules/#{module_id}/items")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            puts "MAKING REQUEST TO: #{uri.request_uri}"
            request = Net::HTTP::Post.new(uri.request_uri)
            request["Authorization"] = "Bearer #{@access_token}"
            request.set_form_data({"module_item[title]" => label,
                                    "module_item[type]" => "ExternalTool",
                                    "module_item[content_id]" =>tool_id,
                                    "module_item[external_url]" => tool_url})
            
            puts "SENDING REQUEST TO ADD TOOL: #{label} TO MODULE"
            response = http.request(request)
            
            puts response.body
            return response.body
            
        end
        
        def publish_module_in_course(course_id, module_id)
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course}/modules/module_id")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Put.new(uri.request_uri)
            request["Authorization"] = "Bearer #{@access_token}"
            request.set_form_data({"module[published]"=>true})
            
            response = http.request(request)
            puts "PUBLISHED MODULE?"
            puts response.body
            return response.body
            
        end
        
        def remove_tool_from_course(course_id, tool_id)
            uri = URI.parse("https://#{@canvas_url}/api/v1/courses/#{course_id}/external_tools/#{tool_id}")
            
            puts "REQUESTING TO REMOVE TOOL AT: #{uri}"
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Delete.new(uri.request_uri)
            
            request["Authorization"] = "Bearer #{@access_token}"
            response = http.request(request)
            
            puts response.body
            return response.body
        end
        
        def start_conversation(to, message)
            uri = URI.parse("https://#{@canvas_url}/api/v1/conversations")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.request_uri)
            request["Authorization"] = "Bearer #{@access_token}"
            
            request.set_form_data({"recipients"=>"#{to}", "subject" => "Attention ASDF GHJKL!", "body"=>message, "group_conversation"=>false, "attachment_ids"=>[], "scope"=>'unread'})
            
            puts "SENDING CONVERSATION START REQUEST TO RECIPIENTS: #{to}"
            response = http.request(request)
            puts response.body
        end
    end
end