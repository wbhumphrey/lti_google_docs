module LtiGoogleDocs
  class ApplicationController < ActionController::Base
    before_action :set_default_headers
    before_filter :cors_preflight_check
    after_filter :cors_set_access_control_headers

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
  end
end
