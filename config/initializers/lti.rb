require 'oauth/request_proxy/rack_request'
require 'yaml'

OAUTH_10_SUPPORT = true

LTI_CONFIG = YAML.load_file(Rails.root.join('../../config/config.yml'))