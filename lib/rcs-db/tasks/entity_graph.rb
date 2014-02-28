require_relative '../graphml'
require_relative '../entity_graph_manager'
require_relative '../tasks'

module RCS
module DB

  class EntitygraphTask
    include RCS::DB::MultiFileTaskType
    include RCS::Tracer

    def ghost?
      @params['ghosts']
    end

    def entities
      @entities ||= begin
        trace :debug, "EntitygraphTask: @params=#{@params.inspect}"
        ids = [@params['id']].flatten.compact

        filters = {}
        filters.merge!('id' => {'$in' => ids}) unless ids.blank?
        filters.merge!(:level.ne => :ghost) unless ghost?

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

      entity_tag_attributes = entity_tag_attributes_proc

      xml = EntityGraphManager.draw(entities, ghost: ghost?)

      yield 'stream', 'map.graphml', {content: xml}

      yield @description = "Ended"
    end
  end

end
end
