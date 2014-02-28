module RCS
  class GraphML

    # The right way to use this class from the outside is calling this method like
    # xml = GraphML.build do
    #   node_attr(:color, :string)
    #   node(:n1, color: :red)
    #   node(:n2)
    #   edge(:n1, :n2)
    # end
    def self.build &block
      instance = new
      instance.instance_eval(&block)
      instance.to_xml
    end

    # Initialize the @data hash adding the root <graphml> tag.
    def initialize
      xmlns = "http://graphml.graphdrawing.org/xmlns"
      xsi   = "http://www.w3.org/2001/XMLSchema-instance"
      loc   = "http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd"

      @data = {:graphml => {:'@xmlns' => xmlns, :'@xmlns:xsi' => xsi, :'@xsi:schemaLocation' => loc}}
    end

    # Convert the @data hash to a valid xml document.
    # @see XmlSimple gem documentation (http://xml-simple.rubyforge.org/).
    def to_xml
      '<?xml version="1.0" encoding="UTF-8"?>' + "\n" +
      XmlSimple.xml_out(@data, {'KeepRoot' => true, 'AttrPrefix' => true, 'ContentKey' => :_content })
    end

    # Define all the possible types of a GraphML-Attribute.
    def self.attr_types
      [:boolean, :int, :long, :float, :double, :string]
    end

    # Adds an GraphML-Attribute to the document.
    # This generates an xml key tag like:
    # <key id="d0" for="node" attr.name="steve" attr.type="string"/>
    def attr _for, id, type, name
      raise "Invalid GraphML-Attribute type: #{type}" unless self.class.attr_types.include?(type)

      @data[:graphml][:key] ||= []
      @data[:graphml][:key] << {:'@id' => id, :'@for' => _for, :'@attr.name' => name, :'@attr.type' => type}
    end

    def node_attr id, type, name = id
      attr :node, id, type, name
    end

    def edge_attr id, type, name = id
      attr :edge, id, type, name
    end

    # Adds or recal the <graph> tag.
    # This generates the following xml:
    # <graph id="graph" edgedefault="directed"></graph>
    def _graph
      @data[:graphml][:graph] ||= {:'@id' => "graph", :'@edgedefault' => "directed"}
    end

    # Adds zero to n <data> tag to the parent tag.
    # @example <data key="color">red</data>
    def data parent, key_values
      return if key_values.empty?
      key_values.each {|key, value| key_values[key] = '' if value.nil? }
      parent[:data] ||= []
      key_values.each { |key, value| parent[:data] << {:'@key' => key, :_content => value} }
    end

    # Adds a <node> tag to the <graph> tag.
    # Adds also the <data> tags inside of it.
    # @example node("id1", color: "red") generates the follwing xml:
    # <node id="id1">
    #   <data key="color">red</data>
    # </node>
    def node id, data = {}
      _graph[:node] ||= []
      elem = {:'@id' => id}
      data elem, data
      _graph[:node] << elem
    end

    # Adds an <edge> tag to the <graph> tag.
    # Adds also the <data> tags inside of it.
    def edge id, source_node, target_node, data = {}, opts = {}
      _graph[:edge] ||= []
      add_ampersat_to_keys(opts)
      elem = {:'@id' => id, :'@source' => source_node, :'@target' => target_node}.merge(opts)

      existing_edge = _graph[:edge].find { |e| e[:'@source'] == elem[:'@source'] and e[:'@target'] == elem[:'@target'] }
      return if existing_edge

      # find specular edges if any
      _graph[:edge].size.times do |index|
        e = _graph[:edge][index]
        if e[:'@source'] == elem[:'@target'] and e[:'@target'] == elem[:'@source']
          _graph[:edge][index][:directed] = false
          return
        end
      end

      data elem, data

      _graph[:edge] << elem
    end

    def add_ampersat_to_keys hash
      hash.keys.each { |key| hash["@#{key}"] = hash[key]; hash.delete(key) }
    end
  end
end
