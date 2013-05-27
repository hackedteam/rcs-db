#
#  Cores handling module
#
require_relative 'db_layer'
require_relative 'grid'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class Core
  extend RCS::Tracer

  def self.load_all
    trace :info, "Loading cores into db..."

    Dir['./cores/*'].each do |core_file|
      name = File.basename(core_file, '.zip')
      version = ''
      begin
        Zip::ZipFile.open(core_file) do |z|
          version = z.file.open('version', "rb") { |f| f.read }.chomp
        end

        make_unique(core_file)

        trace :info, "Load core: #{name} #{version}"

        # delete if already present
        ::Core.where({name: name}).destroy_all

        # replace the new one
        core = ::Core.new
        core.name = name
        core.version = version

        core[:_grid] = GridFS.put(File.open(core_file, 'rb+') {|f| f.read}, {filename: name})
        core[:_grid_size] = File.size(core_file)
        core.save

        File.delete(core_file)
      rescue Exception => e
        trace :error, "Cannot load core #{name}: #{e.message}"
      end
    end

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