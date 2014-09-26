require 'base64'
require 'digest'
require 'openssl'

require 'mojo_auth/version'

#
# MojoAuth
#
# MojoAuth is a set of standard approaches to cross-app authentication based on HMAC
#
class MojoAuth
  DAY_IN_SECONDS = 86_400

  # Create a new random secret
  # @return [String] a new secret based on /dev/random
  def self.create_secret
    random = File.read('/dev/random', 512)
    Base64.encode64(Digest::SHA2.new(512).digest(random))
  end

  # Create a new credential set
  # @param [String] id the identity to be asserted in the credentials
  # @param [String] secret the shared secret with which to create credentials
  # @param [Integer] ttl the duration for which the credentials should be valid in seconds
  # @return [Hash] signed credentials, keys :username and :password
  def self.create_credentials(id: nil, secret: required, ttl: DAY_IN_SECONDS)
    expiry_timestamp = (Time.now.utc + ttl).to_i
    username = [expiry_timestamp, id].join(':')
    { username: username, password: new(secret).sign(username) }
  end

  # Test that credentials are valid
  # @param [Hash] credentials a set of credentials including a :username and a :password
  # @param [String] secret the shared secret against which to test credentials
  # @return [true, false] wether or not the credentials are valid (were created using the specified secret)
  def self.test_credentials(credentials, secret: required)
    new(secret).assert(credentials)
  end

  # Work-around for required named parameters pre Ruby 2.1
  def self.required
    method = caller_locations(1, 1)[0].label
    fail ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
  end

  def initialize(secret)
    @secret = secret
  end

  def sign(username)
    Base64.encode64(OpenSSL::HMAC.digest('sha1', @secret, username))
  end

  def assert(credentials)
    expiry_timestamp, id = credentials[:username].split(':')
    return false if expiry_timestamp.to_i < Time.now.utc.to_i
    return false unless sign(credentials[:username]) == credentials[:password]
    id || true
  end
end
