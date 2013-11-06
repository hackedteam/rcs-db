require_relative '../graphml'
require_relative '../tasks'

module RCS
module DB

  class EntitygraphTask
    include RCS::DB::MultiFileTaskType
    include RCS::Tracer

    def ghosts?
      @params['ghosts']
    end

    def entities
      @entities ||= begin
        trace :debug, "EntitygraphTask: @params=#{@params.inspect}"
        ids = [@params['id']].flatten.compact

        filters = {}
        filters.merge!('id' => {'$in' => ids}) unless ids.blank?
        filters.merge!(:level.ne => :ghost) unless ghosts?

        Entity.path_include(@params['operation']).where(filters).all
      end
    end

    # @see RCS::DB::MultiFileTaskType
    def total
      2
    end

    def entity_tag_attributes_proc
      @entity_tag_attributes_proc ||= Proc.new do |en|
        attributes = {entity_type: en.type, entity_name: en.name, label: en.name}

        if en.type == :position
          attributes.merge!(latitude: en.position[1], longitude: en.position[0], accuracy: en.position_attr['accuracy'])
        end

        attributes
      end
    end

    # @see RCS::DB::MultiFileTaskType
    def next_entry
      @description = "Exporting the graph"

      list = entities
      entity_tag_attributes = entity_tag_attributes_proc

      # The helpers used here are: node_attr, edge_attr, node, edge
      xml = GraphML.build do
        node_attr(:entity_name, :string)
        node_attr(:entity_type, :string)
        node_attr(:latitude, :float)
        node_attr(:longitude, :float)
        node_attr(:accuracy, :float)
        node_attr(:label, :string)

        edge_attr(:link_type, :string)
        edge_attr(:link_level, :string)

        list.each do |en|
          node en.id, entity_tag_attributes.call(en)

          en.links.each do |link|
            opts = {directed: link.versus != :both}
            from, to = (link.versus == :out) ? [en.id, link.le] : [link.le, en.id]
            edge(link.id, from.to_s, to.to_s, {link_type: link.type, link_level: link.level}, opts)
          end
        end
      end

      yield 'stream', 'map.graphml', {content: xml}

      yield @description = "Ended"
    end
  end

end
end
