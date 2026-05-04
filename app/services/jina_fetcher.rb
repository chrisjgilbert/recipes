class JinaFetcher
  class Error < StandardError; end

  TIMEOUT = 12
  RETRIES = 1

  def self.call(url)
    new.call(url)
  end

  def call(url)
    base = ENV.fetch("JINA_READER_BASE", "https://r.jina.ai")
    target = "#{base}/#{url}"

    attempts = 0
    begin
      attempts += 1
      response = conn.get(target)
      raise Error, "Jina returned #{response.status}" unless response.success?
      response.body
    rescue Faraday::Error, Error => e
      raise Error, e.message if attempts > RETRIES
      sleep(0.5 * (2**(attempts - 1)))
      retry
    end
  end

  private

  def conn
    @conn ||= Faraday.new do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = 5
      f.headers["Accept"] = "text/plain"
    end
  end
end
