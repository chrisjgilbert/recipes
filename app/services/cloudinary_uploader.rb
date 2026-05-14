require "base64"
require "digest"

class CloudinaryUploader
  class Error < StandardError; end

  UPLOAD_URL = "https://api.cloudinary.com/v1_1/%s/image/upload"
  TIMEOUT = 30

  def self.call(image_bytes, media_type:)
    new.call(image_bytes, media_type: media_type)
  end

  def call(image_bytes, media_type:)
    timestamp = Time.now.to_i
    data_uri = "data:#{media_type};base64,#{Base64.strict_encode64(image_bytes)}"

    response = conn.post(format(UPLOAD_URL, cloud_name)) do |req|
      req.body = {
        file: data_uri,
        api_key: api_key,
        timestamp: timestamp,
        signature: signature(timestamp)
      }
    end

    raise Error, "Cloudinary returned #{response.status}" unless response.success?

    JSON.parse(response.body).fetch("secure_url")
  rescue Faraday::Error, KeyError => e
    raise Error, e.message
  end

  private

  def signature(timestamp)
    Digest::SHA1.hexdigest("timestamp=#{timestamp}#{api_secret}")
  end

  def cloud_name
    Rails.application.credentials.cloudinary_cloud_name!
  end

  def api_key
    Rails.application.credentials.cloudinary_api_key!
  end

  def api_secret
    Rails.application.credentials.cloudinary_api_secret!
  end

  def conn
    @conn ||= Faraday.new do |f|
      f.request :url_encoded
      f.options.timeout = TIMEOUT
      f.options.open_timeout = 10
    end
  end
end
