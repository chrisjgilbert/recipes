require "nokogiri"

class OgImageFetcher
  TIMEOUT = 10
  SELECTORS = [
    'meta[property="og:image"]',
    'meta[name="og:image"]',
    'meta[name="twitter:image"]',
    'meta[property="twitter:image"]'
  ].freeze

  def self.call(url)
    new.call(url)
  end

  def call(url)
    response = conn.get(url)
    return nil unless response.success?

    doc = Nokogiri::HTML(response.body)
    SELECTORS.each do |selector|
      node = doc.at_css(selector)
      content = node&.[]("content").presence
      return content if content
    end

    nil
  rescue StandardError
    nil
  end

  private

  def conn
    @conn ||= Faraday.new do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = 5
      f.headers["User-Agent"] = "Mozilla/5.0 (compatible; RecipeImporter/1.0)"
    end
  end
end
