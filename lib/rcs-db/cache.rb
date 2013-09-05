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
        klasses.map! { |klass| Object.const_get("#{klass}".titleize) }

        klasses.each do |klass|
          klass.__send__(:include, CachableDocument)
        end

        @observed_classes = klasses
      end

      def self.observed_classes
        @observed_classes
      end

      class Manager
        include Singleton
        include RCS::Tracer

        MAX = 104_857_600 #100mb

        def initialize
          @lock = Mutex.new
          clear
        end

        def observed_classes
          RCS::DB::Cache.observed_classes
        end

        def remove(collection)
          colls = @docs[collection] || []

          colls.each do |key|
            elem = @json.delete(key)
            @size -= elem[2] if elem
          end

          @docs.delete(collection)

          trace :debug, "Cache manager: removed all cache for #{collection}. Size is now #{@size} bytes"
        end

        def clear
          @docs = {}
          @json = {}
          @size = 0
        end

        def cache(key, data, collection)
          if @size >= MAX
            trace :warn, "Cache manager: size limit reached"
            clear
          end

          size = data.size
          @json[key] = [Time.now, data, size]
          
          if collection
            @docs[collection] ||= []
            @docs[collection] << key
          end
          
          @size += size
          
          trace :debug, "Cache manager: cached #{collection || "Array"} #{key}. Size is now: #{@size} bytes"
          data
        end

        def fetch(key)
          @json[key]
        end

        def fetch_or_cache(key, query, collection)

          data = fetch(key)

          if data
            trace :debug, "Cache manager: hit! #{collection || "Array"} #{key}"
            data[1]
          else
            t = Time.now
            json = query.to_json
            el = Time.now - t
            unless collection
              trace :debug, "Cache manager: json generation for array of size #{query.size} took #{el} sec."
            end
            cache(key, json, collection)
          end
        end

        def unsupported(query)
          query.to_json
        end

        def process_mongoid_criteria(query)
          collection = query.klass
          key = Digest::MD5.hexdigest([query.klass, query.selector, query.options].inspect)

          if observed_classes.include?(collection)
            fetch_or_cache(key, query, collection)
          else
            unsupported(query)
          end
        end

        def process_array(array)
          t = Time.now
          key = Digest::MD5.hexdigest(array.inspect)
          el = Time.now - t
          trace :debug, "Cache manager: key generation for array of size #{array.size} took #{el} sec."
          fetch_or_cache(key, array, nil)
        end

        def process(query)
          # @lock.synchronize { process_thread_unsafe(query) }
          process_thread_unsafe(query)
        end

        def process_thread_unsafe(query)
          if query.kind_of?(Array)
            process_array(query)
          elsif query.kind_of?(Mongoid::Criteria)
            process_mongoid_criteria(query)
          else
            unsupported(query)
          end
        end
      end
    end
  end
end
