# For the benefit of NewDomainWorker
require "nokogiri"

class Domain < ActiveRecord::Base
  # Lookup and cache meta information for a domain
  def self.lookup_meta(domain_name)
    # TODO If the last time the meta info was grabbed was a long time ago, refresh it
    # TODO Fix race condition
    domain = find_by(name: domain_name)
    if domain.nil?
      begin
        doc = RestClient.get("http://#{domain_name}")
      rescue RestClient::InternalServerError
        doc = ""
      end

      header = Nokogiri::HTML(doc).at("html head")
      tag = header.at("meta[name='description']") || header.at("meta[name='Description']")
      meta = tag["content"] if tag
      domain = create!(name: domain_name, meta: meta)
    end
    domain.meta
  end
end