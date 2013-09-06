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
          if klass.class == Class
            klass.__send__(:include, CachableDocument)
          elsif klass.class == Module
            old_included_method = klass.method(:included)
            klass.define_singleton_method(:included) do |base|
              old_included_method.call(base)
              base.__send__(:include, RCS::DB::Cache::CachableDocument)
            end
          end
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
        SMALL_ARRAY_SIZE = 8

        def initialize
          @lock = Mutex.new
          clear
        end

        def remove(document)
          document = mongoid_document(document)
          keys = @docs[document]

          return unless keys

          keys.each do |key|
            elem = @json.delete(key)
            @size -= elem[2] if elem
          end

          @docs[document] = []

          trace :debug, "Cache manager: removed all cache for #{document}. Size is now #{@size} bytes."
        end

        def clear
          @docs = {}
          @json = {}
          @size = 0
        end

        def cache(key, data, options = {})
          if @size >= MAX
            trace :warn, "Cache manager: size limit reached."
            clear
          end

          size = data.size
          @json[key] = [Time.now, data, size]
          @size += size

          if options[:bounded_to]
            document = options[:bounded_to]
            @docs[document] ||= []
            @docs[document] << key
          end

          trace :debug, "Cache manager: cached | #{size} bytes | #{options[:bounded_to] || "Array"} | #{options[:uri]} | Total size is now #{@size} bytes"
          data
        end

        def fetch(key)
          @json[key]
        end

        def observed_classes
          RCS::DB::Cache.observed_classes
        end

        def observed_class?(klass)
          list = observed_classes
          list.include?(klass) || (klass.respond_to?(:included) && (klass.ancestors & list).size == 1)
        end

        def fetch_or_cache(key, object, options = {})
          data = fetch(key)

          if data
            trace :debug, "Cache manager: hit | #{data[2]} bytes | #{options[:bounded_to] || "Array"} | #{options[:uri]}"
            data[1]
          else
            cache(key, object.to_json, options)
          end
        end

        def unsupported(query)
          query.to_json
        end

        def mongoid_document(klass)
          return klass if observed_classes.include?(klass)
          mod = (observed_classes & klass.ancestors).first
          return mod if mod
        end

        def process_moped_query(query, options = {})
          document = Object.const_get(query.collection.name.classify)
          document = mongoid_document(document)
          return unsupported(query) unless document
          key = Digest::MD5.hexdigest(query.operation.inspect)

          fetch_or_cache(key, query, options.merge(bounded_to: document))
        end

        def process_mongoid_criteria(criteria, options = {})
          document = mongoid_document(criteria.klass)
          return unsupported(criteria) unless document
          key = Digest::MD5.hexdigest(criteria.query.operation.inspect)

          fetch_or_cache(key, criteria, options.merge(bounded_to: document))
        end

        def process_array(array, options = {})
          if array.size <= SMALL_ARRAY_SIZE
            unsupported(array)
          else
            key = Digest::MD5.hexdigest(array.inspect)
            fetch_or_cache(key, array, options)
          end
        end

        # @note: thread unsafe!
        def process(object, options = {})
          if object.kind_of?(Array)
            process_array(object, options)
          elsif object.respond_to?(:query)
            process_mongoid_criteria(object, options)
          elsif object.kind_of?(Moped::Query)
            process_moped_query(object, options)
          else
            unsupported(object)
          end
        end
      end
    end
  end
end
