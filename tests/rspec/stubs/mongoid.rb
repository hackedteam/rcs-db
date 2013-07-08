module RCS
  module Stubs
    def self.mongoid_env
      {
        'MONGOID_ENV'      => 'yes',
        'MONGOID_DATABASE' => 'rcs-test',
        'MONGOID_HOST'     => 'localhost',
        'MONGOID_PORT'     => '27017'
      }
    end
  end
end

RCS::Stubs.mongoid_env.each do |key, value|
  ENV[key] = value
end
