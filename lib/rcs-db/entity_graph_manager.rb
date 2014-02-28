require_relative 'graphml'

module RCS
  module EntityGraphManager
    extend self

    def draw(entities, **options)
      entity_tag_attributes = entity_tag_attributes_proc

      xml = GraphML.build do
        node_attr(:entity_name, :string)
        node_attr(:entity_type, :string)
        node_attr(:latitude, :float)
        node_attr(:longitude, :float)
        node_attr(:accuracy, :float)
        node_attr(:label, :string)

        edge_attr(:link_type, :string)
        edge_attr(:link_level, :string)

        entities.each do |en|
          next if en.level == :ghost and options[:ghost] != true

          node en.id, entity_tag_attributes.call(en)

          en.links.each do |link|
            opts = {directed: link.versus != :both}
            from, to = (link.versus == :out) ? [en.id, link.le] : [link.le, en.id]
            edge(link.id, from.to_s, to.to_s, {link_type: link.type, link_level: link.level}, opts)
          end
        end
      end

      dump_to_file(options[:file], xml) if options[:file]

      xml
    end

    def dump_to_file(path, xml)
      File.open(path, 'wb') { |f| f.write(xml) }
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
  end
end
