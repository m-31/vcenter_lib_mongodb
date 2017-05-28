require 'time'

require_relative "logging"

module VcenterLibMongodb
  # access vms and their facts from mongo database
  class Mongodb
    include Logging
    attr_reader :connection
    attr_reader :vms_collection
    attr_reader :meta_collection

    # initialize access to mongodb
    #
    # You might want to adjust the logging level, for example:
    #   ::Mongo::Logger.logger.level = logger.level
    #
    # @param connection        mongodb connection, should already be switched to correct database
    # @param vms               symbol for collection that contains vms with their facts
    # @param meta              symbol for collection with update metadata
    def initialize(connection, vms = :vms, meta = :meta)
      @connection = connection
      @vms_collection = vms
      @meta_collection = meta
    end

    # get all vm names
    def all_vms
      collection = connection[vms_collection]
      collection.find.batch_size(999).projection(_id: 1).map { |k| k[:_id] }
    end

    # get vm names that fulfill given query
    #
    # @param query [String] a query for VMs.
    #    nil or white space only string will return all VMs
    # @return [Array<String>] names of nodes that fulfill the query
    def query_vms(query)
      return all_nodes if query_string.nil? || query_string.strip.empty?
      mongo_query = convert.query(query)
      collection = connection[vms_collection]
      collection.find(mongo_query).batch_size(999).projection(_id: 1).map { |k| k[:_id] }
    end

    # get vms and their facts that fulfill given mongodb query
    #
    # @param query[String] a query for VMs
    # @param facts [Array<String>] get these facts in the result, eg ['boot_time'], empty for all
    # @return [Hash<name, <fact , value>>] VM names with their facts and values
    def query_facts(query, facts = [])
      mongo_query = convert.query(query)
      fields = Hash[facts.collect { |fact| [fact.to_sym, 1] }]
      collection = connection[vms_collection]
      result = {}
      collection.find(mongo_query).batch_size(999).projection(fields).each do |values|
        id = values.delete('_id')
        result[id] = values
      end
      result
    end

    # get vms and their facts that fulfill given mongodb query and have at least one
    # value for one the given fact names
    #
    # @param query mongodb query
    # @param facts [Array<String>] get these facts in the result, eg ['fqdn'], empty for all
    def query_facts_exist(query, facts = [])
      result = query_facts(query, facts)
      unless facts.empty?
        result.keep_if do |_k, v|
          facts.any? { |f| !v[f].nil? }
        end
      end
      result
    end

    # get VMs and their facts for a pattern
    #
    # @param query mongodb query
    # @param pattern [RegExp] search for
    # @param facts [Array<String>] get these facts in the result, eg ['fqdn'], empty for all
    # @param facts_found [Array<String>] fact names are added to this array
    # @param check_names [Boolean] also search fact names
    def search_facts(query, pattern, facts = [], facts_found = [], check_names = false)
      mongo_query = convert.query(query)
      collection = connection[vms_collection]
      result = {}
      collection.find(mongo_query).batch_size(999).each do |values|
        id = values.delete('_id')
        found = {}
        values.each do |k, v|
          if v =~ pattern
            found[k] = v
          elsif check_names && k =~ pattern
            found[k] = v
          end
        end
        next if found.empty?
        facts_found.concat(found.keys).uniq!
        facts.each do |f|
          found[f] = values[f]
        end
        result[id] = found
      end
      result
    end

    # get facts for given vm name
    #
    # @param vm [String] vm name
    # @param facts [Array<String>] get these facts in the result, eg ['fqdn'], empty for all
    def single_vm_facts(vm, facts)
      fields = Hash[facts.collect { |fact| [fact.to_sym, 1] }]
      collection = connection[vms_collection]
      result = collection.find(_id: vm).limit(1).batch_size(1).projection(fields).to_a.first
      result.delete("_id") if result
      result
    end

    # get all vms and their facts
    #
    # @param facts [Array<String>] get these facts in the result, eg ['fqdn'], empty for all
    def facts(facts = [])
      fields = Hash[facts.collect { |fact| [fact.to_sym, 1] }]
      collection = connection[vms_collection]
      result = {}
      collection.find.batch_size(999).projection(fields).each do |values|
        id = values.delete('_id')
        result[id] = values
      end
      result
    end

    # get meta informations about updates
    def meta
      collection = connection[meta_collection]
      result = collection.find.first
      result.delete(:_id)
      result
    end

    # update or insert facts for given vm name
    #
    # @param vm [String] vm name
    # @param facts [Hash] facts for the vm
    def vm_update(vm, facts)
      logger.debug "  updating #{vm}"
      connection[vms_collection].find(_id: vm).replace_one(facts,
        upsert:                     true,
        bypass_document_validation: true,
        check_keys:                 false,
        validating_keys:            false)
    rescue ::Mongo::Error::OperationFailure => e
      logger.warn "  updating #{vm} failed with: #{e.message}"
      # mongodb doesn't support keys with a dot
      # see https://docs.mongodb.com/manual/reference/limits/#Restrictions-on-Field-Names
      # as a dirty workaround we delete the document and insert it ;-)
      # The dotted field .. in .. is not valid for storage. (57)
      # .. is an illegal key in MongoDB. Keys may not start with '$' or contain a '.'.
      # (BSON::String::IllegalKey)
      raise e unless e.message =~ /The dotted field / || e.message =~ /is an illegal key/
      logger.warn "    we transform the dots into underline characters"
      begin
        facts = Hash[facts.map { |k, v| [k.tr('.', '_'), v] }]
        connection[vms_collection].find(_id: vm).replace_one(facts,
          upsert: true,
          bypass_document_validation: true,
          check_keys: false,
          validating_keys: false)
      rescue
        logger.error "  inserting #{vm} failed again with: #{e.message}"
      end
    end

    # delete vm data for given vm name
    #
    # @param vm [String] vm name
    def vm_delete(vm)
      connection[vms_collection].find(_id: vm).delete_one
    end

    # update or insert timestamps for given fact update method
    def meta_fact_update(method, ts_begin, ts_end)
      connection[meta_collection].find_one_and_update(
        {},
        {
          '$set' => {
            last_fact_update: {
              ts_begin: ts_begin.iso8601,
              ts_end:   ts_end.iso8601,
              method:   method
            },
            method => {
              ts_begin: ts_begin.iso8601,
              ts_end:   ts_end.iso8601
            }
          }
        },
        { upsert: true }
      )
    end
  end
end
