require 'rcs-common/trace'

module RCS
module Intelligence

module Virtual
  extend Tracer
  extend self

  def process_url_evidence target_entity, url_evidence
    url = url_evidence.data['url']
    virtual_entity = find_virtual_entity_by_url(url)
    return unless virtual_entity

    link_params = {from: target_entity, to: virtual_entity, level: :automatic, type: :virtual, versus: :out, info: url}
    RCS::DB::LinkManager.instance.add_link(link_params)
  end

  def find_virtual_entity_by_url url
    Entity.virtuals.with_handle(:url, url).first
  end
end

end
end
