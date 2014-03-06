require 'rack'
require 'simple_oauth'
require 'json'
require 'oauthenticator/signed_request'

module OAuthenticator
  class Middleware
    # options:
    #
    # - :bypass - a proc which will be called with a Rack::Request, which must have a boolean result. 
    #   if the result is true, authorization checking is bypassed. if false, the request is authenticated 
    #   and responds 401 if not authenticated.
    # - :config_methods - a Module which defines necessary methods for an OAuthenticator::SignedRequest to determine 
    #   if it is validly signed.
    def initialize(app, options={})
      @app=app
      @options = options
      unless @options[:config_methods].is_a?(Module)
        raise ArgumentError, "options[:config_methods] must be a Module"
      end
    end

    def call(env)
      request = Rack::Request.new(env)

      if @options[:bypass] && @options[:bypass].call(request)
        env["oauth.authenticated"] = false
        @app.call(env, request)
      else
        oauth_signed_request_class = OAuthenticator::SignedRequest.including_config(@options[:config_methods])
        oauth_request = oauth_signed_request_class.from_rack_request(request)
        if oauth_request.errors
          body_object = {'errors' => oauth_request.errors}
          response_headers = {"WWW-Authenticate" => %q(OAuth realm="/"), 'Content-Type' => 'application/json'}
          [401, response_headers, [JSON.pretty_generate(body_object)]]
        else
          env["oauth.consumer_key"] = oauth_request.consumer_key
          env["oauth.access_token"] = oauth_request.token
          env["oauth.authenticated"] = true
          @app.call(env)
        end
      end
    end
  end
end