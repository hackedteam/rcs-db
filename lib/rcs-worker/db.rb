require 'rcs-common/trace'
require 'singleton'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'

module RCS
  module Worker
    class DB < RCS::DB::DB
      WORKER_DB_NAME = 'rcs-worker'

      def change_mongo_host(host)
        @_worker_host = host.split(":").first
        @_default_session = nil
      end

      def purge!
        session.collections.each do |collection|
          collection.drop
        end and true
      end

      def session
        @_default_session ||= begin
          host = @_worker_host || 'localhost'
          port = 27018

          session = Moped::Session.new(["#{host}:#{port}"])
          session.use(WORKER_DB_NAME)
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
