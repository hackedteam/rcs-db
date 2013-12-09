require 'rcs-common/trace'
require 'singleton'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'

module RCS
  module Worker
    class DB < RCS::DB::DB
      WORKER_DB_NAME = 'rcs-worker'

      def mongo_connection
        @_worker_mongo_connection ||= begin
          host = RCS::DB::Config.instance.global['CN']
          port = 27017

          super(WORKER_DB_NAME, host, port)
        end
      end
    end

    class GridFS < RCS::DB::GridFS
      def self.db
        RCS::Worker::DB.instance.mongo_connection
      end
    end
  end
end
