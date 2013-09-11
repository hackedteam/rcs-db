#
# Anonymizer installer creation
#

# from RCS::Common
require 'rcs-common/trace'

require 'archive/tar/minitar'

module RCS
module DB

class BuildAnon < Build
  include Archive::Tar

  def initialize
    super
    @platform = 'anon'
  end

  def melt(params)
    trace :debug, "Build: melt #{params}"

    # take the files needed for the communication with RNC
    Dir.mkdir path('bbproxy/etc')
    FileUtils.cp Config.instance.cert('rcs-network.pem'), path('bbproxy/etc/certificate')
    FileUtils.cp Config.instance.cert('rcs-network.sig'), path('bbproxy/etc/signature')

    # the local port to listen on
    File.open(path('managerport'), 'wb') {|f| f.write params['port']}
    
    # create the installer tar gz
    begin
      gz = Zlib::GzipWriter.new(File.open(path('install.tar.gz'), 'wb'))
      output = Minitar::Output.new(gz)

      h = {name: path('bbproxy/etc/certificate'), as: 'bbproxy/etc/certificate'}
      Minitar::pack_file(h, output)

      h = {name: path('bbproxy/etc/signature'), as: 'bbproxy/etc/signature'}
      Minitar::pack_file(h, output)

      h = {name: path('bbproxy/bbproxy'), as: 'bbproxy/bbproxy', mode: 0755}
      Minitar::pack_file(h, output)

      h = {name: path('version'), as: 'bbproxy/etc/version'}
      Minitar::pack_file(h, output)

      h = {name: path('managerport'), as: 'bbproxy/etc/managerport'}
      Minitar::pack_file(h, output)

      h = {name: path('bbproxy/init.d/bbproxy'), as: 'bbproxy/init.d/bbproxy', mode: 0755}
      Minitar::pack_file(h, output)

    ensure
      output.close
    end

    # prepend the install script
    sh = File.open(path('install.sh'), 'rb+') {|f| f.read}
    bin = File.open(path('install.tar.gz'), 'rb+') {|f| f.read}

    File.open(path('install'), 'wb') do |f|
      f.write sh
      f.write bin
    end

    @outputs = ['install']
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|
      @outputs.each do |out|
        z.file.open(out, "w") { |f| f.write File.open(path(out), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

  def unique(core)
    # nothing to do here...
  end

end

end #DB::
end #RCS::
