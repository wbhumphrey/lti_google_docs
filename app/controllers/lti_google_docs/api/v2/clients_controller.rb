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
            @c = Client.find_by(id: params["id"])

            puts @c.inspect
            
            if !@c
                @c = {id: -1}
            end
            
            if params["query"]
                render json: @c
            else
                render "account_info"
            end
        end
        
        # POST add an entry to the clients table
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
        
        def ready_course
            
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
                    #if course already exists...
                puts course
                if course
                    puts "COURSE EXISTS: #{course.inspect}"
                
                    # do nothing, inform user that this course has already been prepared.
                    render text: "The course has already been readied for use with this Canvas instance and this Canvas course."
                    return
                #if not, create it...
                else
                    # create course and associate it with this client
                    course = Course.create(client_id: client.id, canvas_course_id: course_id)
                    
                    puts "CURRENT CANVAS TOKEN BEFORE COURSE LINK ADD: #{session[:canvas_access_token]}"
                    # create "Lab Creator (Step 2)" tool entry into Canvas
                    canvas_client.access_token = session[:canvas_access_token]
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
        
        def auth
            puts "params from auth: #{params}"
            puts "SESSION IN AUTH: #{session[:userid]}"
            ps = {};
    
            puts "REDIRECT URI TO BE SENT: #{google_client.authorization.redirect_uri}"
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
        
        ################## PASSWORD HASHING TO BE RE-FACTORED LATER ################
        
        PBKDF2_ITERATIONS = 20000;
        SALT_BYTE_SIZE = 64;
        HASH_BYTE_SIZE = 64;
        
        HASH_SECTIONS = 4;
        SECTION_DELIMITER = ":";
        ITERATIONS_INDEX = 1;
        SALT_INDEX = 2;
        HASH_INDEX = 3;
        
        def generateToken
           salt = SecureRandom.base64(SALT_BYTE_SIZE);
        end
        
        def createHash(password)
            #create random salt
            salt = SecureRandom.base64(SALT_BYTE_SIZE);
            
            #run algorithm
            pbkdf2 = OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, salt, PBKDF2_ITERATIONS, HASH_BYTE_SIZE);
            
            #return hash of the format: sha1:1000:DEADBEEF:CAFEBABE
            return ['sha1', PBKDF2_ITERATIONS, salt, Base64.encode64(pbkdf2)].join(SECTION_DELIMITER);
        end
        
        def validatePassword(password, correctHash)
            params = correctHash.split(PBKDF2_ITERATIONS);
            return false if params.length != HASH_SECTIONS;
            
            pbkdf2 = Base64.decode64(params[HASH_INDEX]);
            testHash = OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, params[SALT_INDEX], params[ITERATIONS_INDEX].to_i, pbkdf2.length)
            
            return pbkdf2 == testHash
        end
    end
end