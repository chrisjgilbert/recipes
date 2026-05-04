require "rails_helper"

RSpec.describe JinaFetcher do
  before { ENV["JINA_READER_BASE"] = "https://r.jina.test" }

  it "returns body on 200" do
    stub_request(:get, "https://r.jina.test/https://example.com").to_return(body: "hello")
    expect(described_class.call("https://example.com")).to eq("hello")
  end

  it "retries on transient errors and eventually succeeds" do
    stub_request(:get, "https://r.jina.test/https://example.com")
      .to_return({ status: 500 }, { status: 200, body: "ok" })
    expect(described_class.call("https://example.com")).to eq("ok")
  end

  it "raises after exhausting retries" do
    stub_request(:get, "https://r.jina.test/https://example.com").to_return(status: 500)
    expect { described_class.call("https://example.com") }
      .to raise_error(JinaFetcher::Error)
  end
end
