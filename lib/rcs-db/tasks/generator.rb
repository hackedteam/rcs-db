module TaskGenerator
  def self.extended(base)
    base.send :include, InstanceMethods
    base.instance_exec do
      # default values
      @keep_here = false
      @destination = 'temp'
      @gen_type = :invalid
      @filename = nil
      @description = ''
    end
  end
  
  attr_reader :destination, :path, :keep_here, :gen_type, :filename
  
  def store_in(where, path=nil)
    @destination = where
    @path = path
    fail "Task stored in a local file must specify a path!" if @destination == :file and @path.nil?
  end
  
  def keep_on_server(cond = false)
    @keep_here = cond
  end

  def build
    @gen_type = :build
  end
  
  def multi_file
    @gen_type = :multi_file
  end
  
  def single_file(filename)
    @gen_type = :single_file
    @filename = filename
  end
  
  module InstanceMethods
    attr_accessor :description

    def destination
      self.class.destination
    end

    def folder
      self.class.path
    end
    
    def keep_on_server
      self.class.keep_here
    end
    
    def multi_file?
      self.class.gen_type == :multi_file
    end

    def single_file?
      self.class.gen_type == :single_file
    end
    
    def build?
      self.class.gen_type == :build
    end
    
    def filename
      self.class.filename
    end

    def total
      fail "Please define a 'total' method for your #{self.class} class!"
    end
    
    def next_entry
      fail "Please define a 'next_entry' method for your #{self.class} class!"
    end
  end
end