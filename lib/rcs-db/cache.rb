require 'digest/md5'
require 'rcs-common/trace'

module RCS
  module DB
    module Cache

      module CachableDocument
        extend RCS::Tracer
        include RCS::Tracer

        def self.included(base)
          valid_relations = [Mongoid::Relations::Referenced::Many, 
                             Mongoid::Relations::Embedded::Many, 
                             Mongoid::Relations::Referenced::ManyToMany]

          base.relations.each do |name, definition|
            next unless valid_relations.include?(definition[:relation])
            base.relations[name][:before_add] = :__cachable_relation_callback
            base.relations[name][:after_remove] = :__cachable_relation_callback
          end

          base.before_save :__cachable_relation_callback
          base.after_destroy :__cachable_relation_callback

          trace :warn, "Cache enabled for #{base}"
        end

        def __cachable_relation_callback(document = nil)
          Manager.instance.remove(self.class)
          Manager.instance.remove(document.class) if document
        end
      end

      def self.observe(*klasses)
        klasses.each do |klass|
          klass = Object.const_get("#{klass}".titleize)
          klass.__send__(:include, CachableDocument)
        end
      end

      class Manager
        include Singleton
        include RCS::Tracer

        MAX = 104_857_600 #100mb

        def initialize
          clear

          trace :debug, "Cache manager: inizialized"
        end

        def create_key(query)
          k = [query.klass, query.selector, query.options]
          Digest::MD5.hexdigest(k.inspect)
        end

        def remove(collection)
          return unless @docs[collection]

          @docs[collection].each { |key| @json.delete(key) }
          @size -= @sizes[collection]
          @sizes.delete(collection)
          @docs.delete(collection)

          trace :debug, "Cache manager: removed all cache for #{collection}. Size is now #{@size} bytes"
        end

        def clear
          @docs = {}
          @json = {}
          @sizes = {}
          @size = 0
        end

        def cache(collection, key, data)
          if @size >= MAX
            trace :warn, "Cache manager: size limit reached"
            clear
          end

          @json[key] = [Time.now, data]
          
          @docs[collection] ||= []
          @docs[collection] << key
          
          @sizes[collection] ||= 0
          @sizes[collection] += data.size

          @size += data.size
          
          trace :debug, "Cache manager: cached #{collection} #{key}. Size is now: #{@size} bytes"
          data
        end

        def fetch(key)
          @json[key]
        end

        def process(query)
          if !query.kind_of?(Mongoid::Criteria)
            return query.to_json
          end

          collection = query.klass

          if !collection.included_modules.include?(CachableDocument)
            return query.to_json
          end

          key = create_key(query)
          data = fetch(key)

          if data
            trace :debug, "Cache manager: hit! #{collection} #{key}"
            data[1]
          else
            cache(collection, key, query.to_json)
          end
        end
      end
    end
  end
end
