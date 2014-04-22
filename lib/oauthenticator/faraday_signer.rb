require 'faraday'

if Faraday.respond_to?(:register_middleware)
  Faraday.register_middleware(:request, :oauthenticator_signer => proc { OAuthenticator::FaradaySigner })
end
if Faraday::Request.respond_to?(:register_middleware)
  Faraday::Request.register_middleware(:oauthenticator_signer => proc { OAuthenticator::FaradaySigner })
end

module OAuthenticator
  # OAuthenticator Faraday middleware to sign outgoing requests 
  class FaradaySigner
    # options are passed to {OAuthenticator::SignableRequest}. 
    #
    # attributes of the request are added by the middleware, so you should not provide those as optiosn 
    # (it would not make sense to do so on the connection level). 
    #
    # These are the options you should or may provide (see {OAuthenticator::SignableRequest} for details of 
    # what options are required, what options have default or generated values, and what may be omitted):
    #
    # - signature_method
    # - consumer_key
    # - consumer_secret
    # - token
    # - token_secret
    # - version
    # - realm
    # - hash_body?
    def initialize(app, options)
      @app = app
      @options = options
    end

    # do the thing
    def call(request_env)
      request_attributes = {
        :request_method => request_env[:method],
        :uri => request_env[:url],
        :media_type => request_env[:request_headers]['Content-Type'],
        :body => request_env[:body]
      }
      oauthenticator_signable_request = OAuthenticator::SignableRequest.new(@options.merge(request_attributes))
      authorization = oauthenticator_signable_request.authorization
      signed_request_headers = request_env[:request_headers].merge('Authorization' => authorization)
      signed_request_env = request_env.merge(:request_headers => signed_request_headers)
      @app.call(signed_request_env)
    end
  end
end