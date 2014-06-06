require_dependency "lti_google_docs/application_controller"
require 'google/api_client'
require 'json'
require 'net/http'

module LtiGoogleDocs
  class RegisterController < ApplicationController
    CLIENT_ID = "558678724881-mnbk8edutlbrkvk7tu0v00cpqucp1j15.apps.googleusercontent.com"
    CLIENT_SECRET = "E007PYt5yNSaFVwfRjLV2AiB"
    REDIRECT_URI = "http://desolate-reef-8522.herokuapp.com/lti_google_docs/register/google"
    REDIRECT_URI = "http://127.0.0.1:31337/lti_google_docs/register/google"
    SCOPES = ['https://www.googleapis.com/auth/drive']
      
    CANVAS_AUTH_URL = "http://127.0.0.1:3000/login/oauth2/auth"  
    CANVAS_CLIENT_SECRET = "fznpV0Tl9GCjmaPBBvnFNUlz7zkvURu7GRtbXUi4ORsJX955EdoK0bvbnL65a0gZ"
    CANVAS_CLIENT_ID = 2
    CANVAS_REDIRECT_URI = "http://127.0.0.1:31337/lti_google_docs/register/confirmed2"
    def confirmed
        puts "CONFIRMING!!!"
        puts params
    end
      
    def google
        puts "GOOGLING!!!"
        puts params
        
        client = Google::APIClient.new
        client.authorization.client_id = CLIENT_ID
        client.authorization.client_secret = CLIENT_SECRET
        client.authorization.code = params[:code]
        client.authorization.redirect_uri = REDIRECT_URI
        client.authorization.grant_type = 'authorization_code'

        client.authorization.fetch_access_token!
        
        puts "REFRESH TOKEN: #{client.authorization.refresh_token}"
        puts "ACCESS TOKEN: #{client.authorization.access_token}"
        puts "USER ID: #{session[:userid]}"
      
        if User.find_by(userid: session[:userid])
            puts "FOUND EXISTING USER, UPDATING ENTRY"
            User.find_by(userid: session[:userid]).update_attributes(:refresh => client.authorization.refresh_token)
        else    
            puts "NO EXISTING USER FOUND, CREATING ENTRY"
            User.create(userid: session[:userid], refresh: client.authorization.refresh_token);
        end

        # We redirect to a page that automatically closes itself
        # since this is redirected to a popup.
#        redirect_to "/lti_google_docs/register/confirmed"
      redirect_to "/lti_google_docs/register/canvas"
    end
      
    
    def canvas
        ps = {}
        ps[:client_id] = 2
        ps[:redirect_uri] = 'http://127.0.0.1:31337/lti_google_docs/register/confirmed2'
        ps[:response_type] = 'code'

        query = ps.to_query
        url = URI.parse("#{CANVAS_AUTH_URL}?#{query}")

        redirect_to "#{url}"
    end
        
    def confirmed2
        code = params[:code]
        
        client = CanvasClient.new("http://127.0.0.1:3000")
        client.client_id = CANVAS_CLIENT_ID
        client.redirect_uri = CANVAS_REDIRECT_URI
        client.client_secret = CANVAS_CLIENT_SECRET
        client.auth_code = code
        
        client.request_access_token!
        puts "ACCESS TOKEN: #{client.access_token}"
        
        puts client.list_courses
        render text: "ok"
#        puts params
#        if !params[:access_token]
#            puts "NO ACCESS TOKEN YET, NEED TO SEND CODE NOW"
#            code = params[:code]
#            uri = URI.parse("http://127.0.0.1:3000/login/oauth2/token")
#            response = Net::HTTP.post_form(uri, {"client_id"=>CANVAS_CLIENT_ID, "redirect_uri"=>CANVAS_REDIRECT_URI, "client_secret"=>CANVAS_CLIENT_SECRET, "code"=>code})
#
#            puts response.body
#            obj = JSON.parse(response.body)
#            
#            
#            puts "=== NEXT REQUEST! ==="
#            uri2 = URI.parse("http://127.0.0.1:3000/api/v1/courses?access_token=#{obj['access_token']}")
#            res2 = Net::HTTP.get_response(uri2)
#            puts res2.body
#            
#            
#            courses = JSON.parse(res2.body)
#            puts "COURSE 0: #{courses[0]}"
#    
#    
#            puts "==== LIST USERS IN COURSE REQUEST! ==="
#            uri3 = URI.parse("http://127.0.0.1:3000/api/v1/courses/#{courses[0]["id"]}/users?access_token=#{obj['access_token']}")
#            res3 = Net::HTTP.get_response(uri3)
#            puts res3.body
#    
#            render text: obj["access_token"]
#        else
#            puts "WE HAVE ACCESS TOKEN SO WE'RE DONE!"
#        end
        
#        render text: params.to_s
    end
    
    def index
    end
      
  end

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
      
    def request_access_token!
        uri = URI.parse(@auth_uri)
        response = Net::HTTP.post_form(uri, {"client_id"=>@client_id, "redirect_uri"=>@redirect_uri, "client_secret"=>@client_secret, "code"=>@code})
        @access_token = JSON.parse(response.body)['access_token']
    end
    
    def list_courses
        uri = URI.parse("#{@canvas_url}/api/v1/courses?access_token=#{@access_token}")
        response = Net::HTTP.get_response(uri)
        JSON.parse(response.body)
    end
  end
end
