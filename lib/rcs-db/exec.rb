#
#  Execution of commands on different platforms
#

require 'rcs-common/trace'
require 'rbconfig'

module RCS
module DB

class ExecFailed < StandardError
  attr_reader :msg
  attr_reader :command
  attr_reader :exitstatus
  attr_reader :output
  
  def initialize(msg, command=nil, exitstatus=nil, output=nil)
    @msg = msg
    @command = command
    @exitstatus = exitstatus
    @output = output
  end

  def to_s
    str = @msg
    str += " [#{@command}]" if @command
    str += " [#{@exitstatus}]" if @exitstatus
    str += " output: #{@output}" if @output
    return str
  end
end

class CrossPlatform
  extend RCS::Tracer

  class << self
    
    def init
      # select the correct dir based upon the platform we are running on
      case RbConfig::CONFIG['host_os']
        when /darwin/
          @platform = 'osx'
          @ext = ''
          @separator = ':'
        when /mingw/
          @platform = 'win'
          @ext = '.exe'
          @separator = ';'
      end
    end

    def platform
      @platform || init
      @platform
    end

    def ext
      @ext || init
      @ext
    end

    def separator
      @separator || init
      @separator
    end

    def exec(command, params = "", options = {})

      original_command = command

      trace :debug, "Executing: #{File.basename(command)}"

      # append the specific extension for this platform
      command += ext unless command.end_with? ext

      # if it does not exists on osx, try to execute the windows one with wine
      if platform == 'osx' and not File.exist? command
        if File.exist? command + '.exe'
          trace :debug, "Using wine to execute a windows command..."
          command = "wine #{command}.exe"
        end
      end

      # if the file does not exists, search in the path falling back to 'system'
      if not File.exist? command and not command.start_with?('wine')
        # if needed add the path specified to the Environment
        ENV['PATH'] = "#{options[:add_path]}#{separator}" + ENV['PATH'] if options[:add_path]

        trace :debug, "Executing(system): #{command} #{params}"
        success = system command + " " + params

        # restore the environment
        ENV['PATH'] = ENV['PATH'].gsub("#{options[:add_path]}#{separator}", '') if options[:add_path]

        success or raise(ExecFailed.new("failed to execute command", File.basename(original_command) + " #{params}"))
        return
      end

      command += " " + params

      # without options we can use POPEN (needed by the windows dropper)
      if options == {} 
        # redirect the output
        cmd_run = command + " 2>&1" unless command =~ /2>&1/
        process = ''
        output = ''

        trace :debug, "Executing(popen): #{command}"

        IO.popen(cmd_run) {|f|
          output = f.read
          process = Process.waitpid2(f.pid)[1]
        }
        process.success? || raise(ExecFailed.new("failed to execute command", File.basename(original_command) + " #{params}", process.exitstatus, output))
      else
        # setup the pipe to read the output of the child command
        # redirect stderr to stdout and read only stdout
        rd, wr = IO.pipe
        options[:err] = :out
        options[:out] = wr

        trace :debug, "Executing(spawn) [#{options}]: #{command}"

        # execute the whole command and catch the output
        pid = spawn(command, options)

        # wait for the child to die
        Process.waitpid(pid)

        # read its output from the pipe
        wr.close
        output = rd.read

        $?.success? || raise(ExecFailed.new("failed to execute command", File.basename(original_command) + " #{params}", $?.exitstatus, output))
      end
    end

    def exec_with_output(command, params = "", options = {})

      trace :debug, "Executing with output: #{File.basename(command)}"

      ENV['PATH'] = "#{options[:add_path]}#{separator}" + ENV['PATH'] if options[:add_path]

      trace :debug, "Executing(system): #{command} #{params}"

      full_command = command + " " + params

      # execute and capture the output
      output = `#{full_command}`

      # restore the environment
      ENV['PATH'] = ENV['PATH'].gsub("#{options[:add_path]}#{separator}", '') if options[:add_path]

      return output
    end

  end

end

end #DB::
end #RCS::