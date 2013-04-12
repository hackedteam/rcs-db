#
# Controller for License
#

module RCS
module DB

class LicenseController < RESTController

  def limit
    # we use marshalling due to the lack of a deep copy method ...
    limits = Marshal::load(Marshal.dump(LicenseManager.instance.limits)) #LicenseManager.instance.limits.merge({})
    
    # a trick to get the Infinity value
    inf = 1.0/0
    
    # convert the Infinity to null (needed by the JSON deserializer in flex)
    limits[:users] = nil if limits[:users] == inf
    limits[:agents][:total] = nil if limits[:agents][:total] == inf
    limits[:agents][:desktop] = nil if limits[:agents][:desktop] == inf
    limits[:agents][:mobile] = nil if limits[:agents][:mobile] == inf
    limits[:collectors][:collectors] = nil if limits[:collectors][:collectors] == inf
    limits[:collectors][:anonymizers] = nil if limits[:collectors][:anonymizers] == inf
    limits[:nia][0] = nil if limits[:nia][0] == inf
    limits[:shards] = nil if limits[:shards] == inf

    limits[:expiry] = limits[:expiry].to_i
    limits[:maintenance] = limits[:maintenance].to_i

    return ok(limits)
  end
  
  def count
    return ok(LicenseManager.instance.counters)
  end

  def create
    require_auth_level :admin
    require_auth_level :admin_license

    # ensure the temp dir is present
    Dir::mkdir(Config.instance.temp) if not File.directory?(Config.instance.temp)

    # write to a temporary file
    t = Time.now
    name = @session.user[:_id].to_s + "-" + "%10.9f" % t.to_f
    path = Config.instance.temp(name)

    File.open(path, "wb+") { |f| f.write @request[:content]['content'] }

    # load the new license file
    begin
      LicenseManager.instance.new_license(path)
      FileUtils.rm_rf(path)
    rescue Exception => e
      trace :error, "Cannot load new license file: #{e.message}"
      trace :error, "EXCEPTION:" + e.backtrace.join("\n")
      return bad_request("#{e.message}")
    end

    Audit.log :actor => @session.user[:name], :action => 'license.create', :desc => "Updated the license file"

    return ok
  end

end

end #DB::
end #RCS::