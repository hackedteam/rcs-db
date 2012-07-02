#
# copy in lib/rcs-db-release to make it work
#

require 'bundler/setup'
require 'mongo'
require 'rcs-common/trace'
require_relative 'db'

params = [
  # SERVER 2
    # TARGET 1
  {old_target_id: "4fa91bc77523291860000123", target_id: "4fd1d1dc752329133c00190b", agent_id: "4fa91bcc7523291860000380"},
  {old_target_id: "4fa91bc77523291860000123", target_id: "4fd1d1dc752329133c00190b", agent_id: "4fa91bcc7523291860000386"},
  {old_target_id: "4fa91bc77523291860000123", target_id: "4fd1d1dc752329133c00190b", agent_id: "4fa91bcc752329186000038e"},
    # TARGET 2
  {old_target_id: "4fce2aa475232909b8006241", target_id: "4fd1b7d4752329127c01466c", agent_id: "4fce3ece75232909b8006f0a"},
  {old_target_id: "4fce2aa475232909b8006241", target_id: "4fd1b7d4752329127c01466c", agent_id: "4fcf5770752329127c0043b4"},
  {old_target_id: "4fce2aa475232909b8006241", target_id: "4fd1b7d4752329127c01466c", agent_id: "4fcf5b74752329127c004696"},
  {old_target_id: "4fce2aa475232909b8006241", target_id: "4fd1b7d4752329127c01466c", agent_id: "4fd06d15752329127c00b3c8"},
  {old_target_id: "4fce2aa475232909b8006241", target_id: "4fd1b7d4752329127c01466c", agent_id: "4fd1c2f5752329133c0005c9"}
]

def move_evidence(params)
  old_target = ::Item.find(params[:old_target_id])
  target = ::Item.find(params[:target_id])
  agent = ::Item.find(params[:agent_id])

  evidences = Evidence.collection_class(old_target[:_id]).where(:aid => agent[:_id])

  puts "Moving #{evidences.count} evidence for agent #{agent.name} to target #{target.name}"

  # copy the new evidence
  evidences.each do |old_ev|
    # deep copy the evidence from one collection to the other
    new_ev = Evidence.dynamic_new(target[:_id])
    Evidence.deep_copy(old_ev, new_ev)

    # move the binary content
    if old_ev.data['_grid']
      bin = RCS::DB::GridFS.get(old_ev.data['_grid'], old_target[:_id].to_s)
      new_ev.data['_grid'] = RCS::DB::GridFS.put(bin, {filename: agent[:_id].to_s}, target[:_id].to_s) unless bin.nil?
      new_ev.data['_grid_size'] = old_ev.data['_grid_size']
    end

    # save the new one
    new_ev.save

    # delete the old one. NOTE CAREFULLY:
    # we use delete + explicit grid, since the callback in the destroy will fail
    # because the parent of aid in the evidence is already the new one
    old_ev.delete
    RCS::DB::GridFS.delete(old_ev.data['_grid'], old_target[:_id].to_s) unless old_ev.data['_grid'].nil?

    puts "Moved evidence #{old_ev[:_id]} to #{new_ev[:_id]}"
  end

  puts "Moving finished for #{agent._kind} #{agent.name}"
end

RCS::DB::DB.instance.connect

params.each do |p|
  begin
    move_evidence p
  rescue Mongo::OperationFailure
    retry
  end
end
