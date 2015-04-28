require 'domainatrix'
require 'unirest'

class VerifyNamecheap
  include Sidekiq::Worker
  sidekiq_options :queue => :verify_domains
  
  def perform(page_id, crawl_id, options={})
    puts 'performing verify namecheap'
    processor_name = options['processor_name']
    # page = Page.using(:master).where(id: page_id).first
    
    page = JSON.parse($redis.get(options['redis_id']))
    puts "verify namecheap: the page object is #{page}"
    
    begin
      if page.count > 0
        puts 'found page to verify namecheap'
        url = Domainatrix.parse("#{page['url']}")
        if !url.domain.empty? && !url.public_suffix.empty?
          puts "here is the parsed url #{page['url']}"
          parsed_url = url.domain + "." + url.public_suffix
          unless Page.using("#{processor_name}").where("simple_url IS NOT NULL AND site_id = ?", page['site_id'].to_i).map(&:simple_url).include?(parsed_url)
            puts "checking url #{parsed_url} on namecheap"
            uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/#{parsed_url}")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.request_uri)
            request["X-Mashape-Key"] = "6CWhVxnwLhmshW8UaLSYUSlMocdqp1kkOR4jsnmEFj0MrrHB5T"
            request["Accept"] = "application/json"
            response = http.request(request)
            json = JSON.parse(response.read_body)
            puts 'saving verified domain'
            tlds = [".gov", ".edu"]
            if json['available'].to_s == 'true' && !Rails.cache.read(["crawl/#{crawl_id}/available"]).include?("#{parsed_url}") && !tlds.any?{|tld| parsed_url.include?(tld)}         
              new_page = Page.using("#{processor_name}").create(status_code: page['status_code'], url: page['url'], internal: page['internal'], site_id: page['site_id'], found_on: "#{page['found_on']}", simple_url: "#{parsed_url}", verified: true, available: "#{json['available']}", crawl_id: page['crawl_id'])
              
              urls = Rails.cache.read(["crawl/#{crawl_id}/available"])
              Rails.cache.write(["crawl/#{crawl_id}/available"], urls.push("#{parsed_url}"))
              
              Rails.cache.increment(["crawl/#{crawl_id}/expired_domains"])
              Rails.cache.increment(["site/#{page['site_id']}/expired_domains"])
              
              MozStats.perform_async(new_page.id, parsed_url, 'processor_name' => processor_name)
              MajesticStats.perform_async(new_page.id, parsed_url, 'processor_name' => processor_name)
            end
          end
        end
      end
    rescue
      nil
    end
  end
  
  def on_complete(status, options)
    batch = VerifyNamecheapBatch.where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      app = Site.using(:main_shard).find(batch.site_id).crawl.heroku_app
      app.update(verified: 'finished') if app
      puts 'finished verifying all namecheap domains'
    end
  end
  
  
  def self.test
    uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/howimidoing.com")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request["X-Mashape-Key"] = "6CWhVxnwLhmshW8UaLSYUSlMocdqp1kkOR4jsnmEFj0MrrHB5T"
    request["Accept"] = "application/json"
    response = http.request(request)
    json = JSON.parse(response.read_body)
    json['available']
    return json
  end
  
end