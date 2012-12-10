require 'rubygems'
require 'httparty'

require 'constant_contact'
require 'constant_contact/base_resource'
require 'constant_contact/contact'
require 'constant_contact/contact_list'
require 'constant_contact/activity'

module ConstantContact

    include HTTParty
    
    format :xml
    headers 'Accept'        => 'application/atom+xml'
    headers 'Content-Type'  => 'application/atom+xml'
    
    class << self
      # Create a connection to the Constant Contact API using your login credentials
      def setup( user, pass, api_key )
        basic_auth "#{api_key}%#{user}", pass
        base_uri "https://api.constantcontact.com/ws/customers/#{user.downcase}"
      end

      def setup_oauth( user, token )
      #  headers 'Authorization' => "Bearer #{token}"
        default_params :access_token => token
        base_uri "https://api.constantcontact.com/ws/customers/#{user.downcase}"
      end

      def get_authorize_url( api_key, redirect_uri )
        "https://oauth2.constantcontact.com/oauth2/oauth/siteowner/authorize?response_type=code&client_id=#{api_key}&redirect_uri=#{redirect_uri}"
      end

      def authorize_code( api_key, api_secret, code, redirect_uri)
        debug_on
        base_uri "https://oauth2.constantcontact.com"
        data = get('/oauth2/oauth/token', 
          { :query => 
              { :grant_type => 'authorization_code', 
                :client_id => api_key, 
                :client_secret => api_secret, 
                :code => code, 
                :redirect_uri => redirect_uri},
            :format => :json})
        if data.code == 200 # success
          return data #ActiveSupport::JSON.decode(data.body)
        else
          raise BaseResource.create_exception(data)
        end
      end
      
      def debug_on
        debug_output $stderr
      end
    end

    class Error < StandardError  
      def initialize(message, code)
        super
        @sub_message = message
        @code = code
      end
      def message
        "HTTP Status Code: #{@code}, message: #{super.message}"
      end
 
      attr_reader :code, :sub_message
    end

end
