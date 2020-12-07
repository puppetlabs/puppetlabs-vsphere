# frozen_string_literal: true

# The Puppet Extensions Module.
module PuppetX
  # PuppetLabs Module.
  module Puppetlabs
    # We purposefully inherit from Exception here due to PUP-3656
    # If we throw something based on StandardError prior to Puppet 4
    # the exception will prevent the prefetch, but the provider will
    # continue to run with incorrect data.
    class PrefetchError < RuntimeError
      def initialize(type, message = nil)
        @message = message
        @type = type
      end

      # Prefetch Error
      def to_s
        ''"Puppet detected a problem with the information returned from vSphere when accessing #{@type}. The specific error was:
#{@message}"''
      end
    end
  end
end
