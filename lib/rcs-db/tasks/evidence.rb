# encoding: UTF-8

require_relative '../tasks'

require 'cgi'

require 'rcs-common/utf16le'

module RCS
  module DB

    class EvidenceTask
      include RCS::DB::MultiFileTaskType
      include RCS::Tracer

      def internal_filename
        'evidence.html'
      end

      def total
        num = ::Evidence.filtered_count @params
        trace :info, "Exporting #{num} evidence..."
        return num
      end

      def next_entry
        @description = "Exporting #{@total} evidence"

        evidence = ::Evidence.filter @params

        export(evidence, index: :da, target: @params['filter']['target']) do |type, filename, opts|
          yield type, filename, opts
        end

        yield @description = "Ended"
      end

      ######################################################################################################

      def html_page_header
        <<-eof
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
      <link rel="stylesheet" type="text/css" href="style/evidence.css">
      <link rel="stylesheet" type="text/css" href="../style/evidence.css">
    </head>
    <body>
        eof
      end

      def html_page_footer
        <<-eof
    </body>
    </html>
        eof
      end

      def html_evidence_table_header(day)
        <<-eof
      <table>
        <caption>Evidence for #{day}</caption>
        <thead>
          <tr>
            <th scope="col" class="id">id</th>
            <th scope="col" class="agent">agent</th>
            <th scope="col" class="acquired">acquired</th>
            <th scope="col" class="received">received</th>
            <th scope="col" class="rel">tag</th>
            <th scope="col" class="type">type</th>
            <th scope="col" class="info">info</th>
            <th scope="col" class="note">note</th>
          </tr>
        </thead>
        <tbody>
        eof
      end

      def html_evidence_table_row(row)
        <<-eof
      <tr>
        <td class="id">#{row[:_id]}</td><td class="agent">#{row[:agent]}</td>
        <td class="acquired">#{Time.at(row[:da]).strftime('%Y-%m-%d %H:%M:%S')}</td><td class="received">#{Time.at(row[:dr]).strftime('%Y-%m-%d %H:%M:%S')}</td>
        <td class="rel#{row[:rel]}"></td><td class="type">#{row[:type]}</td>
        <td class="info">#{html_data_renderer(row)}</td><td class="note">#{row[:note]}</td>
      </tr>
        eof
      end

      def html_table_footer
        <<-eof
        </tbody>
      </table>
        eof
      end

      def html_summary_table_header
        <<-eof
      <table>
        <caption>Evidence for </caption>
        <thead>
          <tr>
            <th scope="col" class="date">date</th>
            <th scope="col" class="evidence">evidence statistics by hour</th>
          </tr>
        </thead>
        <tbody>
        eof
      end

      def html_summary_table_row(row)
        <<-eof
      <tr>
        <td class="date"><a href="#{row[:date]}/index.html">#{row[:date]}</a></td><td class="evidence">#{html_stat_renderer(row[:num])}</td>
      </tr>
        eof
      end

      def html_data_renderer(row)
        table = "<table class=\"inner\"><tbody>"
        # expand all the metadata
        row[:data].each_pair do |k, v|
          next if ['_grid', '_grid_size', 'md5', 'body', 'status'].include? k
          v = CGI::escapeHTML(v.to_s)
          v.gsub! /\n/, '<br>' if v.class == String
          table << "<tr><td class=\"inner\">#{k}</td><td class=\"inner\">#{v}</td></tr>"
        end
        # add binary content
        case row[:type]
          when 'screenshot', 'camera', 'print'
            table << "<tr><td class=\"inner\">image</td><td class=\"inner\">#{html_image(row[:data]['_grid'].to_s + '.jpg')}</td></tr>"
          when 'mouse'
            table << "<tr><td class=\"inner\">image</td><td class=\"inner\">#{html_image(row[:data]['_grid'].to_s + '.jpg', 40)}</td></tr>"
          when 'call', 'mic'
            unless row[:data]['_grid'].nil?
              table << "<tr><td class=\"inner\">audio</td><td class=\"inner\">#{html_mp3_player(row[:data]['_grid'].to_s + '.mp3')}</td></tr>"
            end
          when 'file'
            if row[:data]['type'] == :capture
              table << "<tr><td class=\"inner\">file</td><td class=\"inner\"><a href=\"#{row[:data]['_grid'].to_s + File.extname(row[:data]['path'])}\" title=\"Download\"><font size=3><b>⇊</b></font></a></td></tr>"
            end
          when 'message'
            if row[:data]['type'] == :mail
              table << "<tr><td class=\"inner\">body</td><td class=\"inner\"><a href=\"#{row[:data]['_grid'].to_s + '.txt'}\" title=\"Download\"><font size=3><b>⇊</b></font></a></td></tr>"
            end
        end
        table << "</tbody></table>"
        table
      end

      def html_stat_renderer(data)
        max = data.max
        table = "<table class=\"stat\"><tbody><tr>"
        data.each_with_index do |value|
          h = value * 20 / max
          table << "<td class=\"stat\"><img src=\"style/stat.png\" height=\"#{h}\" width=\"6\"></td>"
        end
        table << "</tr><tr>"
        # put the hours
        (0..23).each {|h| table << "<td  class=\"stat\">#{'%02d' % h}</td>"}
        table << "</tr></tbody></table>"
        table
      end

      def html_image(image, size=140)
        <<-eof
    <a href="#{image}"><img src="#{image}" height="#{size}" ></a>
        eof
      end

      def html_mp3_player(mp3)
        <<-eof
    <audio src="#{mp3}" controls>
        HTML5 audio not supported
    </audio>
    <a href="#{mp3}" title="Download"><font size=3><b>⇊</b></font></a>
        eof
      end

      def begin_new_file(day)
        out = {}
        out[:name] = File.join(day, 'index.html')
        out[:content] = html_page_header
        out[:content] << html_evidence_table_header(day)
        return out
      end

      def end_file(out)
        out[:content] << html_table_footer
        out[:content] << html_page_footer
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
              name << '.txt'
            end
        end
        name
      end

      def dump_file(day, grid_id, name, target)
        file = GridFS.to_tmp grid_id, target
        return File.join(day, name), file
      end

      def create_summary(summary)
        out = {}
        out[:name] = 'index.html'
        out[:content] = html_page_header
        out[:content] << html_summary_table_header

        summary.each_pair do |k,v|
          out[:content] << html_summary_table_row(date: k, num: v)
        end

        out[:content] << html_table_footer
        out[:content] << html_page_footer

        return out
      end

      def expand_styles
        Zip::ZipFile.open(Config.instance.file('export.zip')) do |z|
          z.each do |f|
            yield f.name, z.file.open(f.name, "rb") { |c| c.read }
          end
        end
      end

      def export(evidence, opts)

        # expand the sytles in the dest dir
        expand_styles do |name, content|
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
        # TODO: in mogoid 3.0.0 we should be able to specify :timeout => false on queries

        chunk = 100
        cursor = 0
        total = evidence.count

        first_element = true
        while cursor < total do

          grid_dumps = []

          evidence.limit(chunk).skip(cursor).each_with_index do |e, i|
            # get the day of the current evidence
            day = Time.at(e[opts[:index]]).strftime('%Y-%m-%d')
            # get the hour of the evidence
            hour = Time.at(e[opts[:index]]).strftime('%H').to_i

            # this is the first element
            if first_element == true
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
              e[:agent] = ::Item.find(e[:aid]).name
            rescue
              e[:agent] = 'unknown'
            end

            # write the current evidence
            out[:content] << html_evidence_table_row(e)

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
              trace :debug, "Exporting GRID file #{g[:id].inspect} to #{g[:file_name]}"
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
        if first_element == false
          end_file out
          yield 'stream', out[:name], {content: out[:content]}
        end

        # create the total summary of the exported evidence
        out = create_summary summary
        yield 'stream', out[:name], {content: out[:content]}

      end

    end

  end # DB
end # RCS