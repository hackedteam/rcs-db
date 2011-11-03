#
#  Execution of commands on different platforms
#

require 'rcs-common/trace'

module RCS
module DB

class CrossPlatform
  extend RCS::Tracer

  class << self
    
    def init
      # select the correct dir based upon the platform we are running on
      case RUBY_PLATFORM
        when /darwin/
          @platform = 'osx'
          @ext = ''
        when /mingw/
          @platform = 'win'
          @ext = '.exe'
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

    def exec(command, params)

      # append the specific extension for this platform
      command += ext

      original_command = command

      # if the file does not exist on windows, we have huge problems
      if platform == 'win' and not File.exist? command
        raise "File not found: #{command}"
      end

      # if it does not exists on osx, try to execute the windows one with wine
      if platform == 'osx' and not File.exist? command
        command += '.exe'
        if File.exist? command
          trace :debug, "Using wine to execute a windows command..."
          command.prepend("wine ")
        else
          raise "File not found: #{command}"
        end
      end

      command += " " + params

      #trace :debug, "Executing: #{command}"

      # execute the whole command and catch the output
      output = %x[#{command}]
      $?.success? || raise("failed to execute command [#{File.basename(original_command)}] output: #{output}")

    end

  end

end

end #DB::
end #RCS::