require 'securerandom'
require 'openssl'
require 'base64'

module LtiGoogleDocs::Api::V2
    class ClientsController < ApplicationController
        
        
        # GET list all clients
        def index
            render text: ["Token generated: \n",generateToken].join
        end
        
        #GET show an entry in the clients table with a specific id
        def show
            @c = Client.find_by(id: params["id"])
            
            puts @c.inspect
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
            
            @client = Client.create(client_name: client_name, canvas_url: canvas_url, canvas_clientid: canvas_clientid, canvas_client_secret: canvas_client_secret, contact_email: contact_email, client_id: client_id, client_secret: client_secret)
            @client.save
            
            
            render json: @client
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