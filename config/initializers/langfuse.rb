return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

Langfuse.configure do |config|
  config.public_key = ENV["LANGFUSE_PUBLIC_KEY"]
  config.secret_key = ENV["LANGFUSE_SECRET_KEY"]
  config.host = ENV["LANGFUSE_HOST"].presence || "https://cloud.langfuse.com"
  config.debug = Rails.env.development?
end
