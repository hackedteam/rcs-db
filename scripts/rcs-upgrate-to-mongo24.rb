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
# - (and then usual update procedure)


require 'open3'
require 'logger'
require 'mongoid'

MONGO_BINARIES_PATH = "C:\\RCS\\DB\\mongodb\\win"
MONGO_SERVER_ADDR = "127.0.0.1:27017"
MONGOS24_BIN_PATH = "C:\\temp\\mongos24.exe" # TODO: change


# Handle logging and errors

def logger
  @logger ||= Logger.new $stdout #TODO: change
end

def log_and_raise msg
  @logger.error msg
  raise msg
end



# MongoDB related methods

def mongo_session
  @mongo_session ||= begin
    logger.debug "Establishing a new Moped session to #{MONGO_SERVER_ADDR}"
    Moped::Session.new [MONGO_SERVER_ADDR]
  end
end

def mongo_renew_session
  @mongo_session = nil
  mongo_session
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

def mongo_24?
  mongo_version.start_with? "2.4"
end

def mongo_start_balancer
  mongo_session.command "$eval" =>  "sh.startBalancer()"
end

def mongo_stop_balancer
  mongo_session.command "$eval" =>  "sh.stopBalancer()"
end

# TODO: do not word this way :(
def mongo_upgrade
  command = "#{MONGOS24_BIN_PATH} --configdb localhost --upgrade"
  stdin, stdout, stderr, thread = Open3.popen3 command
  exit = false
  error = false

  while true
    stdout_lines = stdout.readlines
    stderr_lines = stderr.readlines
    
    stderr_lines.each do |line| 
      logger.error line
      error = line
    end

    stdout_lines.each do |line| 
      logger.debug line
      exit = true if line =~ /balancer id.*started at/
      error = line if line =~ /ERROR\:/
    end

    break if exit || !thread.alive?
    sleep 0.1
  end

  log_and_raise "Command \"#{command}\" generates error \"#{error}\"" if error
end



# Windows methods: safe command execution, service ctrl, etc.

def windows_execute command
  logger.debug "Executing \"#{command}]\""
  out, err = Open3.capture3 command
  log_and_raise "Command \"#{command}\" generates error \"#{err}\"" unless err.empty?
  out
end

def windows_service service_name, action
  windows_execute "net #{action} #{service_name}"
end

def windows_diskfree
  result = windows_execute 'fsutil volume diskfree c: | FIND "avail free"'
  result.scan(/.*\:\s*(\d+)/).flatten.first.to_i
end



# The whole upgrade procedure to version 2.4

if mongo_24?
  logger.info "Mongo 2.4 is already installed."
  return
end

if windows_diskfree < mongo_config_db_size*5
  log_and_raise "There is not enough free space for the mongoDB config database."
end

mongo_stop_balancer
windows_service "RCS Master Router", :stop
mongo_upgrade
mongo_renew_session

if mongos22?
  log_and_raise "There should be mongoDB 2.4 running at this point."
end

mongo_start_balancer
