require 'logger'

# library for easy acces to vcenter informations
module VcenterLibMongodb
  require_relative 'vcenter_lib_mongodb/logging'
  require_relative 'vcenter_lib_mongodb/version'
  require_relative 'vcenter_lib_mongodb/mongodb'
  require_relative 'vcenter_lib_mongodb/updater'

  def logger
    unless @logger
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
    end

    @logger
  end
end
