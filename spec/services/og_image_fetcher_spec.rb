require "rails_helper"

RSpec.describe OgImageFetcher do
  let(:url) { "https://example.com/pasta" }

  it "returns og:image content when present" do
    stub_request(:get, url).to_return(body: <<~HTML, headers: { "Content-Type" => "text/html" })
      <html><head>
        <meta property="og:image" content="https://example.com/pasta.jpg">
      </head></html>
    HTML

    expect(described_class.call(url)).to eq("https://example.com/pasta.jpg")
  end

  it "falls back to twitter:image when og:image is absent" do
    stub_request(:get, url).to_return(body: <<~HTML, headers: { "Content-Type" => "text/html" })
      <html><head>
        <meta name="twitter:image" content="https://example.com/twitter.jpg">
      </head></html>
    HTML

    expect(described_class.call(url)).to eq("https://example.com/twitter.jpg")
  end

  it "prefers og:image over twitter:image" do
    stub_request(:get, url).to_return(body: <<~HTML, headers: { "Content-Type" => "text/html" })
      <html><head>
        <meta property="og:image" content="https://example.com/og.jpg">
        <meta name="twitter:image" content="https://example.com/twitter.jpg">
      </head></html>
    HTML

    expect(described_class.call(url)).to eq("https://example.com/og.jpg")
  end

  it "returns nil when no image meta tags are present" do
    stub_request(:get, url).to_return(body: "<html><head><title>No image</title></head></html>")

    expect(described_class.call(url)).to be_nil
  end

  it "returns nil on non-200 response" do
    stub_request(:get, url).to_return(status: 404)

    expect(described_class.call(url)).to be_nil
  end

  it "returns nil on network error" do
    stub_request(:get, url).to_raise(Faraday::ConnectionFailed.new("refused"))

    expect(described_class.call(url)).to be_nil
  end
end
