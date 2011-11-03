#
#  Execution of commands on different platforms
#

module RCS
module DB

class CrossPlatform

  class << self
    
    def init
      # select the correct dir based upon the platform we are running on
      case RUBY_PLATFORM
        when /darwin/
          @platform = 'macos'
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
      
    end

  end

end

end #DB::
end #RCS::