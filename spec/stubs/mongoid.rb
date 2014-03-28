module RCS
  module Stubs
    def self.mongoid_env
      {
        'MONGOID_ENV'             => 'yes',

        'MONGOID_DATABASE'        => 'rcs-test',
        'MONGOID_HOST'            => '127.0.0.1',
        'MONGOID_PORT'            => '27017',

        'MONGOID_WORKER_DATABASE' => 'rcs-worker-test',
        'MONGOID_WORKER_HOST'     => '127.0.0.1',
        'MONGOID_WORKER_PORT'     => '27018',
      }
    end
  end
end

RCS::Stubs.mongoid_env.each do |key, value|
  ENV[key] = value
end
