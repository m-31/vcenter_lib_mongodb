require_relative "logging"

module VcenterLibMongodb
  # update vms data from source to destination
  class Updater
    include Logging

    attr_reader :source
    attr_reader :destination

    def initialize(source, destination)
      @source = source
      @destination = destination
    end

    # update by deleting missing vms and get a complete map of vms with facts
    # and update or insert facts for each one
    #
    # for example: 1633 vms in 60.70 seconds
    def update
      logger.info "update started (full update)"
      tsb = Time.now
      complete = source.facts
      source_vms = complete.keys
      destination_vms = destination.all_vms
      delete_missing(destination_vms, source_vms)
      errors = false

      complete.each do |vm, facts|
        begin
          destination.vm_update(vm, facts)
        rescue
          errors = true
          logger.error $!
          pp facts
        end
      end
      tse = Time.now
      logger.info "update updated #{source_vms.size} vms in #{tse - tsb}"
      if errors
        logger.error "we don't update metadata information due to update errors"
      else
        destination.meta_fact_update("update", tsb, tse)
      end
    end

    private

    def delete_missing(destination_vms, source_vms)
      missing = destination_vms - source_vms
      missing.each do |vm|
        destination.vm_delete(vm)
      end
      logger.info "  deleted #{missing.size} vms"
    end
  end
end
