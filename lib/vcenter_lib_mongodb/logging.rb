require 'logger'
require 'vcenter_lib/logging'

module VcenterLibMongodb
  # for logger access just include this module
  module Logging
    class << self
      attr_writer :logger

      def logger
        @logger ||= VcenterLib::Logging.logger
      end
    end

    # addition
    def self.included(base)
      class << base
        def logger
          # :nocov:
          Logging.logger
          # :nocov:
        end

        def logger=(logger)
          # :nocov:
          Logging.logger = logger
          # :nocov:
        end
      end
    end

    def logger
      Logging.logger
    end

    def logger=(logger)
      Logging.logger = logger
    end
  end
end
