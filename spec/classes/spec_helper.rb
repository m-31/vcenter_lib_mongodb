require_relative '../../lib/vcenter_lib_mongodb'

# no logging output during spec tests
VcenterLibMongodb::Logging.logger.level = Logger::FATAL
