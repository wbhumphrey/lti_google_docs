require_dependency "lti_google_docs/application_controller"

require 'securerandom'
require 'openssl'
require 'base64'
require 'json'

module LtiGoogleDocs::Api::V2
    class ClientsController < LtiGoogleDocs::ApplicationController
        
        
        # GET list all clients
        def index
            render text: ["Token generated: \n",generateToken].join
        end
        
        #GET show an entry in the clients table with a specific id
        def show
            #retrieve entry from clients table
            @c = Client.find_by(id: params["id"])
            
            #if no entry exists for that id, return an entry with -1
            if !@c
                @c = {id: -1}
            end
            
            #further, if the url says to use json, return the entry as json
            if params["query"]
                render json: @c
            else
                #otherwise, render the account_info page
                render "account_info"
            end
        end
        
        # POST add an entry to the clients table, from outside of Canvas.
        def create
            
            puts "CREATING NEW CLIENT!"
            puts params.inspect
            
            client_name = params["client_name"]
            canvas_url = params["canvas_url"]
            canvas_clientid = params["canvas_clientid"]
            canvas_client_secret = params["canvas_client_secret"]
            contact_email = params["contact_email"]
            
            #generate client id for us
            client_id = "#{contact_email}#{generateToken}"
            
            #generate client secret for us
            client_secret = "#{generateToken}"
            
            @client = Client.create(client_name: client_name,
                                    canvas_url: canvas_url,
                                    canvas_clientid: canvas_clientid,
                                    canvas_client_secret: canvas_client_secret,
                                    contact_email: contact_email,
                                    client_id: client_id,
                                    client_secret: client_secret)
            @client.save
    
            render json: @client
        end
        
        # POST as an LTI from within Canvas
        def ready_course
            
            # THIS IS AN LTI ENTRY POINT,
            # WE WILL GET ALL SORTS OF CANVAS INFO HERE.
            
            
            if !params[:custom_canvas_user_id] || params[:custom_canvas_user_id] == nil
                render text: "No canvas user id was sent. Maybe the person who installed the LTI did not specify public access?"
                return
            end
            
            lti_user = User.find_by(canvas_user_id: params[:custom_canvas_user_id])
            
            ### REMOVE THIS AFTER TESTING ###
            
#            @canvas_user_id = params[:custom_canvas_user_id]
#            @canvas_server_address = params[:custom_canvas_api_domain]
#            render "retrieve_canvas_token"
#            return
            
            ### REMOVE ABOVE AFTER TESTING ###
            
            if !lti_user
                #tell the client to retrieve the canvas token from the canvas server
                
                @oauth_consumer_key = Clients.find_by(client_id: params[:oauth_consumer_key]).canvas_clientid
                @canvas_user_id = params[:custom_canvas_user_id]
                @canvas_server_address = params[:custom_canvas_api_domain]
                render "retrieve_canvas_token"
                return
            end
            # continue as normal...
            puts "CONTINUE AS NORMAL..."
            canvas_access_token = lti_user.canvas_access_token    

            @ready_course = true;
            
            puts "PREPARING COURSE FOR INTEGRATION!"
            if request.post?
                # retrieve client id from Clients table, associated with params: oauth_consumer_key
                key = params["oauth_consumer_key"]
                client = Client.find_by(client_id: key)
                if !client
                    render text: "Sorry, there doesn't appear to be a client associated with your key and secret. Please contact your administrator."
                    return
                end    
                puts "CLIENT EXISTS WITH KEY: #{key}";
                
                # retrieve course id, should be in params: custom_canvas_course_id
                course_id = params["custom_canvas_course_id"]
                
                #check for existing course with these two ids
                course = Course.find_by(client_id: client.id, canvas_course_id: course_id)
                if course
                    puts "COURSE EXISTS: #{course.inspect}"
                
                    # do nothing, inform user that this course has already been prepared.
                    render text: "The course has already been readied for use with this Canvas instance and this Canvas course."
                    return
                #if not, create it...
                else
                    # create course and associate it with this client
                    course = Course.create(client_id: client.id, canvas_course_id: course_id)
                    # create "Lab Creator (Step 2)" tool entry into Canvas
                    canvas_client = new_canvas_client(client)
                    canvas_client.access_token = lti_user.canvas_access_token
                    canvas_client.add_course_link(course_id,
                                                "Lab Creator (Step 2)",
                                                "www.google.com",
                                                key,
                                                client.client_secret,
                                                "http://#{get_my_ip_address}:#{request.port}/lti_google_docs/api/v2/labs",
                                                "Lab Creator (Step 2)")
                
                    json_string = canvas_client.add_module_to_course(course.canvas_course_id, "Labs")
                    module_body = JSON.parse(json_string);
                
                    if !module_body["errors"]
                        puts "MODULE CREATION SUCCESS"
                        course.update(canvas_module_id: module_body["id"])
                        course.save
                    else
                        puts "SOMETHING WENT WRONG TRYING TO CREATE THE MODULE"
                    end
                
                        #/api/v2/courses/course_id/labs/new
                    # remove tool entry associated with this controller, if possible.
                    # inform user they are now able to create labs via course navigation link.
                    
                    @msg = "Refresh the page and you should now see \"Lab Creator (Step 2)\" in the course navigation menu!";
                    render "ready_course"
                    return
                end
            else
                #if this is not a post, render message detailing that we don't like GET requests.
                render text: "Nothing to see here..."
            end
        end

        # PUT/PATCH update a client with a specific id
        def update
            puts "INSIDE UPDATE!";
            puts params.inspect
            
            @c = Client.find_by(id: params["id"]);
            @c.client_name = params["client_name"];
            @c.canvas_url = params["canvas_url"];
            @c.canvas_client_secret = params["canvas_client_secret"];
            @c.canvas_clientid = params["canvas_clientid"];
            @c.contact_email = params["contact_email"];
            
            @c.save
            
            render json: @c
        end
        
        # DELETE remove an entry to the clients table with a specific id
        def destroy
            render text: "Not supported yet."
        end
        
        # GET show the web page for registration
        def new
            render "registration"
        end
        
        def new_canvas_client(client)
            cc = LtiGoogleDocs::CanvasClient.new(client.canvas_url)
            cc.client_id = client.canvas_clientid
            cc.client_secret = client.canvas_client_secret
            
            #this needs to be domain_tool_is_running_on:port_tool_is_using/lti_google_docs/register/confirmed2
            cc.redirect_uri = "http://"+get_my_ip_address+":31337/lti_google_docs/register/confirmed2"
            return cc
        end
        
    end
end