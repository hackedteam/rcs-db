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
      number_of_photos = entities.inject(0) { |tot, e| tot += e.photos.size }
      entities.size + number_of_photos + 1
    end

    # Must be implemented
    # @see RCS::DB::MultiFileTaskType
    # The MultiFileTaskType#run method calls next_entry with a block. Each time the block
    # is yieled a file/stream is written and the @current (step) variable is incremented
    def next_entry
      @description = "Exporting #{entities.size} entities"

      entities.each do |entity|
        template = EntityTaskTemplate.new name: :show, entity: entity
        entity.photos.each do |photo_id|
          yield 'stream', template.photo_path(photo_id), {content: entity.photo_data(photo_id)}
        end
        yield 'stream', template.path, {content: template.render}
      end

      yield @description = "Ended"
    end
  end


  # To isolate the binding passed to ERB
  # @params: the template name ("name")
  #          the entity instance to be passed to ("entity")
  class EntityTaskTemplate < OpenStruct
    def render
      template_path = File.join self.class.templates_folder, "#{name}.erb"
      template = ERB.new File.new(template_path).read, nil, "%"
      template.result binding
    end

    def self.templates_folder
      @templates_folder ||= File.join File.dirname(__FILE__), 'entity'
    end

    # View helpers

    def path
      "#{entity.type.to_s.pluralize}/#{entity.id}/show.html".downcase
    end

    def photo_url id
      "#{id}.jpg".downcase
    end

    def photo_path id
      "#{entity.type.to_s.pluralize}/#{entity.id}/#{id}.jpg".downcase
    end

    def most_contacted
      return [] if entity.type != :target
      result = Aggregate.most_contacted entity.target_id, 'num' => 10
      result.flatten
    end

    def google_map
      return if entity.position.blank?
      lat_lon = entity.position.reverse.join ','
      '<div class="google_map"><iframe width="100%" height="400" frameborder="0" scrolling="yes" marginheight="0" marginwidth="0"
      src="http://maps.google.it/maps?f=q&amp;source=s_q&amp;hl=en&amp;geocode=&amp;q='+lat_lon+'&amp;aq=&amp;ie=UTF8&amp;
      t=m&amp;z=14&amp;ll='+lat_lon+'&amp;output=embed"></iframe></div>'
    end
  end

end
end
