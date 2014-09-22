require 'google/api_client'
require_dependency '../../lib/lti_google_docs/Configuration'
require_dependency '../../lib/lti_google_docs/CanvasClient'

require 'socket'
require 'securerandom'
require 'openssl'
require 'base64'
require 'json'

module LtiGoogleDocs
    class ApplicationController < ActionController::Base
        before_action :set_default_headers
        before_action :test_before
        before_filter :cors_preflight_check
        after_filter :cors_set_access_control_headers

        def retrieve_configuration
            conf = Configuration.new
            @google_client_id = conf.client_id
            @google_client_secret = conf.client_secret

            #puts "#CONFIG GOOGLE REDIRECT URI: #{conf.redirect_uri}"
            @google_redirect_uri = conf.redirect_uri
            @google_scopes = conf.scopes
            @google_scopes.push("https://www.googleapis.com/auth/userinfo")

            @canvas_auth_url = conf.canvas_auth_url
            @canvas_client_secret = conf.canvas_client_secret
            @canvas_client_id = conf.canvas_client_id
            @canvas_redirect_uri = conf.canvas_redirect_uri
        end
        
        def test_before
            retrieve_configuration
            
            #render lti error message unless there was no error
            if request.post?
                render tool_provider.lti_msg unless !tool_provider.lti_msg
            end
        end

        def set_default_headers
#            puts "SETTING DEFAULT HEADERS!"
          response.headers['X-Frame-Options'] = 'ALLOWALL'
        end

        # For all responses in this controller, return the CORS access control headers.
        def cors_set_access_control_headers
          headers['Access-Control-Allow-Origin'] = '*'
          headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, OPTIONS'
          headers['Access-Control-Request-Method'] = '*'
          headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
          headers['Access-Control-Max-Age'] = "1728000"
        end

        # If this is a preflight OPTIONS request, then short-circuit the
        # request, return only the necessary headers and return an empty
        # text/plain.
        def cors_preflight_check
#            puts "CORS PREFLIGHT CHECK"
          if request.method == :options
            headers['Access-Control-Allow-Origin'] = '*'
            headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
            headers['Access-Control-Allow-Headers'] = '*'
            headers['Access-Control-Max-Age'] = '1728000'
            render :text => '', :content_type => 'text/plain'
          end
        end

#        $oauth_creds = {"test" => "secret", "testing" => "supersecret"}

        def tool_provider
          return @tp if @tp

          key = params["oauth_consumer_key"]
          client = Client.find_by(client_id: key)
          secret = nil;
          if client
            secret = client.client_secret
          end
         
#          key = params['oauth_consumer_key']
#          secret = $oauth_creds[key]
          @tp = IMS::LTI::ToolProvider.new(key, secret, params)

          if !key
            @tp.lti_msg = "No consumer key"
          elsif !secret
            @tp.lti_msg = "Your consumer didn't use a recognized key."
            # tp.lti_errorlog = "You did it wrong!"
          elsif !@tp.valid_request?(request)
            @tp.lti_msg = "The OAuth signature was invalid"
          elsif Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
            @tp.lti_msg = "Your request is too old."
          elsif was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
            @tp.lti_msg = "This nonce has already been used"
          end

          return @tp
        end

        def was_nonce_used_in_last_x_minutes?(nonce, minutes)
          return false
        end

        def google_client
            return @gc if @gc

            @gc = Google::APIClient.new
            @gc.authorization.client_id = @google_client_id
            @gc.authorization.client_secret = @google_client_secret
            @gc.authorization.redirect_uri = @google_redirect_uri
            
            puts "GOOGLE SCOPES: #{@google_scopes}"
            @gc.authorization.scope = @google_scopes[0]

            return @gc
        end

        def canvas_client
            return @cc if @cc
            
            #HARDCODING THIS URL IS A TERRIBLE IDEA!
            # THIS SHOULD BE ACCESSED FROM AN ACCOUNTS DATABASE TABLE OR SUCH
            @cc = LtiGoogleDocs::CanvasClient.new("http://127.0.0.1:3000")
            @cc.client_id = @canvas_client_id
            @cc.redirect_uri = @canvas_redirect_uri
            @cc.client_secret = @canvas_client_secret
            
            return @cc
        end
        
        def is_google_access_token_valid?(access_token)
            if !access_token then return false end
            
            google_client.authorization.access_token = access_token
            begin
                drive = google_client.discovered_api('drive', 'v2')
                api_result = google_client.execute(:api_method => drive.files.list, :parameters => {})
                if api_result.status != 200
                    return false
                end
            rescue
                return false
            end
            
            return true
        end
    
        def retrieve_access_token(refresh_token)
            google_client.authorization.refresh_token = refresh_token
#            google_client.authorization.additional_parameters = {:access_type => 'offline'}
            puts "REFRESHING TOKEN WITH: #{google_client.authorization.refresh_token}"
            google_client.authorization.grant_type = 'refresh_token'

            google_client.authorization.fetch_access_token!

            google_client.authorization.access_token
        end
      
        def get_my_ip_address
            #Socket::getaddrinfo(Socket.gethostname, "echo", Socket::AF_INET)[0][3]
            Socket::gethostname
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
           return SecureRandom.base64(SALT_BYTE_SIZE)
        end
        
        def createHash(password)
            #create random salt
            salt = SecureRandom.base64(SALT_BYTE_SIZE)
            
            #run algorithm
            pbkdf2 = OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, salt, PBKDF2_ITERATIONS, HASH_BYTE_SIZE)
            
            #return hash of the format: sha1:1000:DEADBEEF:CAFEBABE
            return ['sha1', PBKDF2_ITERATIONS, salt, Base64.encode64(pbkdf2)].join(SECTION_DELIMITER)
        end
        
        def validatePassword(password, correctHash)
            params = correctHash.split(PBKDF2_ITERATIONS)
            return false if params.length != HASH_SECTIONS
            
            pbkdf2 = Base64.decode64(params[HASH_INDEX])
            testHash = OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, params[SALT_INDEX], params[ITERATIONS_INDEX].to_i, pbkdf2.length)
            
            return pbkdf2 == testHash
        end
    end
end
