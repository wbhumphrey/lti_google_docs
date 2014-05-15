module LtiGoogleDocs
  class ApplicationController < ActionController::Base
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
      elsif !tp.valid_request?(request)
        @tp.lti_msg = "The OAuth signature was invalid"
      elsif Time.now.utc.to_i - tp.request_oauth_timestamp.to_i > 60*60
        @tp.lti_msg = "Your request is too old."
      elsif was_nonce_used_in_last_x_minutes?(tp.request_oauth_nonce, 60)
        @tp.lti_msg = "This nonce has already been used"
      end

      return @tp
    end

    def was_nonce_used_in_last_x_minutes?(nonce, minutes)
      return false
    end
  end
end
