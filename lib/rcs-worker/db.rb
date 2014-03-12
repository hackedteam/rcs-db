require 'rcs-common/trace'
require 'digest/md5'
require 'singleton'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'

module RCS
  module Worker
    class DB < RCS::DB::DB
      WORKER_DB_NAME = 'rcs-worker'

      def change_mongo_host(host)
        Thread.current[:"[mongoid]:rcs_worker_host"] = host.split(":").first
      end

      def purge!
        session.collections.each do |collection|
          collection.drop
        end and true
      end

      def session
        host    = Thread.current[:"[mongoid]:rcs_worker_host"] || 'localhost'
        port    = 27018
        db_name = WORKER_DB_NAME

        session_hash = Digest::MD5.hexdigest("#{host}#{port}#{db_name}")[0..9]

        Thread.current[:"[mongoid]:session_rcs_worker_#{session_hash}"] ||= begin
          session = Moped::Session.new(["#{host}:#{port}"])
          session.use(db_name)
          session
        end
      end
    end

    class GridFS < RCS::DB::GridFS
      def self.session
        RCS::Worker::DB.instance.session
      end
    end
  end
end
