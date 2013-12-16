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
        @mongo_db = nil
      end

      def mongo_connection
        host = @_worker_host || 'localhost'
        port = 27018

        super(WORKER_DB_NAME, host, port)
      end
    end

    class GridFS < RCS::DB::GridFS
      def self.db
        RCS::Worker::DB.instance.mongo_connection
      end
    end
  end
end
