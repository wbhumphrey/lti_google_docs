module LtiGoogleDocs
    class Configuration
        def initialize
            puts "GETTING CONFIGURATION!"
            config = LTI_CONFIG
#            config = YAML.load_file(File.join(__dir__, '../../', 'config.yml'))
            puts config.inspect
            @client_id = config['Google_Credentials']['client_id']
            @client_secret = config['Google_Credentials']['client_secret']
            @redirect_uri = config['Google_Credentials']['redirect_uri']
            @scopes = ["#{config['Google_Credentials']['scopes']}"]

           @canvas_client_id = config['Canvas_Credentials']['CANVAS_CLIENT_ID']
           @canvas_auth_url = config['Canvas_Credentials']['CANVAS_AUTH_URL']
           @canvas_client_secret = config['Canvas_Credentials']['CANVAS_CLIENT_SECRET']
           @canvas_redirect_uri = config['Canvas_Credentials']['CANVAS_REDIRECT_URI']
        end

        def client_id
            @client_id
        end

        def client_secret
            @client_secret
        end

        def redirect_uri
            @redirect_uri
        end

        def scopes
            @scopes
        end

        def canvas_client_id
            @canvas_client_id
        end

        def canvas_auth_url
            @canvas_auth_url
        end

        def canvas_client_secret
            @canvas_client_secret
        end

        def canvas_redirect_uri
            @canvas_redirect_uri
        end
    end
end