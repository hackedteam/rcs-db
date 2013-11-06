require_relative '../graphml'
require_relative '../tasks'

module RCS
module DB

  class EntitygraphTask
    include RCS::DB::MultiFileTaskType
    include RCS::Tracer

    def entities
      @entities ||= begin
        trace :debug, "EntitygraphTask: @params=#{@params.inspect}"
        ids = [@params['id']].flatten.compact
        filters = {'id' => {'$in' => ids}} unless ids.blank?
        Entity.path_include(@params['operation']).where(filters || {}).all
      end
    end

    # Must be implemented
    # @see RCS::DB::MultiFileTaskType
    # Is used to size the client progressbar. Should equals the number of "yield" called
    # in the #next_entry method.
    def total
      2
    end

    # Must be implemented
    # @see RCS::DB::MultiFileTaskType
    # The MultiFileTaskType#run method calls next_entry with a block. Each time the block
    # is yieled a file/stream is written and the @current (step) variable is incremented
    def next_entry
      @description = "Exporting the graph"

      list = entities
      list_ids = entities.map { |e| e.id.to_s }
      unique_edges = []

      # The helpers used here are: node_attr, edge_attr, node, edge
      xml = GraphML.build do
        node_attr(:entity_name, :string)
        node_attr(:entity_type, :string)
        node_attr(:latitude, :float)
        node_attr(:longitude, :float)
        node_attr(:accuracy, :float)

        edge_attr(:link_type, :string)
        edge_attr(:link_level, :string)

        list.each do |en|
          attributes = {entity_type: en.type, entity_name: en.name}
          if en.type == :position
            attributes.merge!(latitude: en.position[1], longitude: en.position[0], accuracy: en.position_attr['accuracy'])
          end
          node en.id, attributes

          en.links.each do |link|
            unique_edges_key = [en.id.to_s, link.le.to_s].sort.join("-")
            next if unique_edges.include?(unique_edges_key)

            val = case link.versus
              when :out then [en.id, link.le]
              when :in then [link.le, en.id]
              else [en.id, link.le, {directed: false}]
            end

            if list_ids.include?(val[0].to_s) or list_ids.include?(val[1].to_s)
              edge link.id, val[0], val[1], {link_type: link.type, link_level: link.level}, (val[2] || {})
            end
            unique_edges << unique_edges_key
          end
        end
      end

      yield 'stream', 'map.graphml', {content: xml}

      yield @description = "Ended"
    end
  end

end
end
