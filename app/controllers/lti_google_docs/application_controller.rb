require 'google/api_client'
require '../../lib/lti_google_docs/Configuration'
require '../../lib/lti_google_docs/CanvasClient'
module LtiGoogleDocs
    class ApplicationController < ActionController::Base
        before_action :set_default_headers
        before_filter :cors_preflight_check
        after_filter :cors_set_access_control_headers

        #Load our configuration information for Google API access 
        def initialize
            super

            conf = LtiGoogleDocs::Configuration.new
            puts "APP CONTROLLER CONFIG: #{conf.inspect}"
            @google_client_id = conf.client_id
            @google_client_secret = conf.client_secret
            @google_redirect_uri = conf.redirect_uri
            @google_scopes = conf.scopes
            
            @canvas_auth_url = conf.canvas_auth_url
            @canvas_client_secret = conf.canvas_client_secret
            @canvas_client_id = conf.canvas_client_id
            @canvas_redirect_uri = conf.canvas_redirect_uri
        end

        def set_default_headers
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
          if request.method == :options
            headers['Access-Control-Allow-Origin'] = '*'
            headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
            headers['Access-Control-Allow-Headers'] = '*'
            headers['Access-Control-Max-Age'] = '1728000'
            render :text => '', :content_type => 'text/plain'
          end
        end

        $oauth_creds = {"test" => "secret", "testing" => "supersecret"}

        def tool_provider
          return @tp if @tp

          key = params['oauth_consumer_key']
          secret = $oauth_creds[key]
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
    
        def is_access_token_valid?
            if !session[:google_access_token] then return false end
            return is_google_access_token_valid?(session[:google_access_token])
        end
    
        def retrieve_access_token(refresh_token)
            google_client.authorization.refresh_token = refresh_token
#            google_client.authorization.additional_parameters = {:access_type => 'offline'}
            puts "REFRESHING TOKEN WITH: #{google_client.authorization.refresh_token}"
            google_client.authorization.grant_type = 'refresh_token'

            google_client.authorization.fetch_access_token!

            google_client.authorization.access_token
        end
    end


end
