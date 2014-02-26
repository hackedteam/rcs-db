require_release 'rcs-db/config'
require_relative 'blk_file'

module RCS
  module Money
    class BlocksFolder
      attr_reader :path

      def initialize(currency, path)
        @path     = path
        @currency = currency
      end

      def files
        Dir["#{@path}/blk*.dat"].sort.map do |path|
          name = File.basename(path).downcase

          blk_file = BlkFile.for(@currency).find_or_initialize_by(name: name)
          blk_file.update_attributes(path: path)
          blk_file
        end
      end

      def size
        files.sum(&:filesize)
      end

      def days_since_last_update
        _files = files
        return 0 if _files.empty?

        p = _files.last.path

        mtime = [File.mtime(p), File.ctime(p)].max

        day_diff = (Time.now - mtime) / (3600 * 24)
        day_diff.round(1)
      end

      def import_percentage
        _files = files
        return 0 if _files.empty?

        sum = _files.inject(0) { |sum, blk_file| sum += blk_file.import_percentage }
        medium = (sum / _files.count).round(2)
      end

      def self.configured_path(currency, win_drive_letter)
        RCS::DB::Config.instance.load_from_file if RCS::DB::Config.instance.global.empty?
        user = RCS::DB::Config.instance.global['MONEY_USER']
        "#{win_drive_letter}:/Users/#{user}/AppData/Roaming/#{currency.to_s.capitalize}/blocks" if user
      end

      # @see: https://en.bitcoin.it/wiki/Data_directory
      def self.discover(currency)
        win_drive_letter = ENV['HOMEDRIVE'].to_s.empty? ? 'C' : ENV['HOMEDRIVE'][0]
        win_app_data = ENV['APPDATA'].to_s.gsub("\\", "/")

        paths = [
          "#{win_app_data}/#{currency.to_s.capitalize}/blocks",
          "#{win_drive_letter}:/Users/Administrator/AppData/Roaming/#{currency.to_s.capitalize}/blocks",
          "#{ENV['HOME']}/Library/Application Support/#{currency.to_s.capitalize}/blocks"
        ]

        path = paths.find { |p| Dir.exists?(p) } || configured_path(currency, win_drive_letter)

        new(currency, path) if path
      end
    end
  end
end
