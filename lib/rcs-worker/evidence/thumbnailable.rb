require 'digest/md5'
require 'fileutils'
require 'base64'

module Thumbnailable
  def windows?
    RbConfig::CONFIG['host_os'] =~ /mingw/
  end

  def convert_bin
    if windows?
      File.expand_path("../../libs/imagemagick/win/convert.exe", __FILE__)
    else
      "convert"
    end
  end

  def convert_command
    p    = temp_path
    size = 80
    ds   = size * 2

    "#{convert_bin} -define jpeg:size=#{ds}x#{ds} \"#{p}\" -thumbnail #{size}x#{size}^ -gravity center -extent #{size}x#{size} -quality 30 \"#{p}\""
  end

  def temp_path
    @_temp_path ||= begin
      name = Digest::MD5.hexdigest("#{self[:ident]}#{self[:instance]}#{rand}") + ".jpg"
      RCS::DB::Config.instance.temp(name)
    end
  end

  def create_temp_folder
    @@_temp_folder_created ||= FileUtils.mkdir_p(File.dirname(temp_path))
  end

  def valid_grid_content?
    self[:grid_content].respond_to?(:size) and self[:grid_content].size > 0
  end

  def create_thumbnail
    self[:data] ||= {}

    return unless valid_grid_content?

    create_temp_folder

    # Dump the image data into a temp file
    File.open(temp_path, 'wb') { |f| f.write(self[:grid_content]) }

    # Convert it to a thumbnail
    return unless system(convert_command)


    # Read the thubmnail and put in the data hash
    File.open(temp_path, 'rb') do |f|
      self[:data][:thumb] = Base64.encode64(f.read)
    end
  rescue Exception => ex
    trace(:error, "Unable to create thumbnail for #{self[:type].to_s.upcase} evidence of agent #{self[:ident]}:#{self[:instance]}: #{ex.message}") if respond_to?(:trace)
    self[:data].delete(:thumb)
  ensure
    FileUtils.rm_f(temp_path)
  end
end
