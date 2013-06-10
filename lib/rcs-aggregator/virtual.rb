require 'uri'

module RCS
module Aggregator

# Handling virtual aggregations
module VirtualAggregator
  extend RCS::Tracer
  extend self

  # Extract the "url" and the "host" from the given URL evidence.
  def extract url_evidence
    visited_url  = url_evidence.data['url']
    date_aquired = url_evidence.da

    [{time: date_aquired, type: :url, url: visited_url, host: host(visited_url)}]
  end

  # Returns nil is the url is invalid, otherwise returns the host
  # of the given url without "www.".
  def host url
    parsed = URI.parse(url)
    return nil unless valid_url_scheme?(parsed.scheme)
    h = parsed.host
    h.gsub(/\Awww\./i, '').downcase if h
  rescue URI::InvalidURIError => error
    nil
  end

  def valid_url_scheme? scheme
    scheme = "#{scheme}".strip.downcase
    %w[http https shttp ftp sftp smb ssh].include?(scheme)
  end
end

end
end
