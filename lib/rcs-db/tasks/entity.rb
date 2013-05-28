require_relative '../tasks'
require 'erb'
require 'ostruct'


module RCS
module DB

  class EntityTask
    include RCS::DB::MultiFileTaskType
    include RCS::Tracer

    def entities
      @entities ||= begin
        filters = {id: @params[:id]} if @params[:id]
        Entity.where(filters || {}).all
      end
    end

    # Must be implemented
    # @see RCS::DB::MultiFileTaskType
    # Is used to size the client progressbar. Should equals the number of "yield" called
    # in the #next_entry method
    def total
      entities.size + 1
    end

    # Must be implemented
    # @see RCS::DB::MultiFileTaskType
    # The MultiFileTaskType#run method calls next_entry with a block. Each time the block
    # is yieled a file/stream is written and the @current (step) variable is incremented
    def next_entry
      @description = "Exporting #{total} entities"

      entities.each do |entity|
        html = EntityTaskTemplate.new(name: :show, entity: entity).render
        # TODO
        yield 'stream', "find_a_file_name", {content: html}
      end

      yield @description = "Ended"
    end
  end


  # To isolate the binding passed to ERB
  # @params: the template name ("name")
  #          the entity instance to be passed to ("entity")
  class EntityTaskTemplate < OpenStruct
    def templates_folder
      File.dirname __FILE__
    end

    def render
      template_path = File.join templates_folder, "entity", "#{name}.erb"
      template = ERB.new File.new(template_path).read, nil, "%"
      template.result binding
    end
  end

end
end
