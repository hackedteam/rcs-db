#!/usr/bin/env ruby
# encoding: utf-8

# --------------------------------------------------------------
# This script will be called from the NSIS installer to update 
# MongoDB from version 2.2 (RCS 8.3.X) to version 2.4 (RCS 9)
# --------------------------------------------------------------

# Steps are:
# - issue sh.stopBalancer() to mongos
# - kill only mongos
# - execute mongos24 --upgrade
# - issue sh.startBalancer() to mongos (24)
# - (begin usual update procedure)


require 'logger'
require 'mongoid'

MONGO_BINARIES_PATH = "C:\\RCS\\DB\\mongodb\\win"
MONGO_SERVER_ADDR = "127.0.0.1:27017"



# Handle logging

def logger
  @logger ||= Logger.new $stdout
end



# MongoDB related methods

def mongo_session opts = {}
  if @mongo_session and !opts[:new]
    @mongo_session
  else
    logger.debug "Establishing a new Moped session to #{MONGO_SERVER_ADDR}"
    @mongo_session = Moped::Session.new [MONGO_SERVER_ADDR]
  end
end

def mongo_config_db_size
  config_values = mongo_session.databases["databases"].find { |db| db["name"] == "config" }
  config_values["sizeOnDisk"]
end

def mongo_version
  mongo_session.command(buildinfo: 1)["version"]
end

def mongo_22?
  mongo_version.start_with? "2.2"
end
