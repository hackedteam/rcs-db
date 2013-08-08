require_relative '../tasks'

module RCS
module DB

class FilesystemTask
  include RCS::DB::SingleFileTaskType

  def internal_filename
    'filesystem.csv'
  end

  def total
    # filter by target
    target = Item.where({_id: @params['filter']['target']}).first
    return not_found("Target not found") if target.nil?

    # filter by agent
    if @params['filter'].has_key? 'agent'
      agent = Item.where({_id: @params['filter']['agent']}).first
      return not_found("Agent not found") if agent.nil?
    end

    # copy remaining filtering criteria (if any)
    filtering = Evidence.target(target[:_id]).where({:type => 'filesystem'})
    filtering = filtering.any_in(:aid => [agent[:_id]]) unless agent.nil?

    return filtering.count
  end
  
  def next_entry
    @description = "Exporting filesystem structure"

    # filter by target
    target = Item.where({_id: @params['filter']['target']}).first
    return not_found("Target not found") if target.nil?

    # filter by agent
    if @params['filter'].has_key? 'agent'
      agent = Item.where({_id: @params['filter']['agent']}).first
      return not_found("Agent not found") if agent.nil?
    end

    # copy remaining filtering criteria (if any)
    filtering = Evidence.target(target[:_id]).where({:type => 'filesystem'})
    filtering = filtering.any_in(:aid => [agent[:_id]]) unless agent.nil?

    # header
    yield ['agent', 'path', 'date', 'size'].to_csv

    # perform de-duplication and sorting at app-layer and not in mongo
    # because the data set can be larger the mongo is able to handle
    data = filtering.to_a

    data.uniq! {|x| x[:data]['path']}
    data.sort! {|x, y| x[:data]['path'].downcase <=> y[:data]['path'].downcase}
    
    # one row per evidence
    data.each do |fs|
      agent = Item.find(fs.aid)
      yield [agent.name, fs.data['path'], Time.at(fs.da).getutc, fs.data['size'].to_i.to_s_bytes].to_csv
    end

  end
end

end # DB
end # RCS