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

      template = EntityTaskTemplate.new erb: :index, entities: entities
      yield 'stream', "index.html", {content: template.render}

      entities.each do |entity|
        entity.photos.each do |photo_id|
          yield 'stream', "#{entity.id}/#{photo_id}.jpg", {content: entity.photo_data(photo_id)}
        end

        template = EntityTaskTemplate.new erb: :show, entity: entity
        yield 'stream', "#{entity.id}/show.html", {content: template.render}
      end

      yield @description = "Ended"
    end
  end


  # To isolate the binding passed to ERB
  class EntityTaskTemplate < OpenStruct
    def render
      template_path = File.join self.class.templates_folder, "#{erb}.erb"
      template = ERB.new File.new(template_path).read, nil, "%"
      template.result binding
    end

    def self.templates_folder
      @templates_folder ||= File.join File.dirname(__FILE__), 'entity'
    end

    # View helpers

    def photo_url photo_id
      "#{photo_id}.jpg"
    end

    def entity_url entity
      "#{entity.id}/show.html"
    end

    def most_contacted entity
      return [] if entity.type != :target
      result = Aggregate.most_contacted entity.target_id, 'num' => 10
      result.flatten
    end

    def google_map lon_lat
      return if lon_lat.blank?
      lat_lon = lon_lat.reverse.join ','
      '<div class="google_map"><iframe width="100%" height="400" frameborder="0" scrolling="yes" marginheight="0" marginwidth="0"
      src="http://maps.google.it/maps?f=q&amp;source=s_q&amp;hl=en&amp;geocode=&amp;q='+lat_lon+'&amp;aq=&amp;ie=UTF8&amp;
      t=m&amp;z=14&amp;ll='+lat_lon+'&amp;output=embed"></iframe></div>'
    end
  end

end
end
