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
    filtering = Evidence.collection_class(target[:_id]).where({:type => 'filesystem'})
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
    filtering = Evidence.collection_class(target[:_id]).where({:type => 'filesystem'})
    filtering = filtering.any_in(:aid => [agent[:_id]]) unless agent.nil?

    # header
    yield ['path', 'date', 'size'].to_csv

    # one row per evidence
    filtering.order_by([["data.path", :asc]]).each do |fs|
      yield [fs.data['path'], fs.da, fs.data['size']].to_csv
    end

  end
end

end # DB
end # RCS