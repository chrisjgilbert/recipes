require "rails_helper"

RSpec.describe CloudinaryUploader do
  let(:cloud_name) { "testcloud" }
  let(:api_key) { "key123" }
  let(:api_secret) { "secret456" }
  let(:upload_url) { "https://api.cloudinary.com/v1_1/testcloud/image/upload" }
  let(:image_bytes) { "fakeimagebytes" }
  let(:media_type) { "image/jpeg" }

  before do
    allow(Rails.application.credentials).to receive(:cloudinary_cloud_name!).and_return(cloud_name)
    allow(Rails.application.credentials).to receive(:cloudinary_api_key!).and_return(api_key)
    allow(Rails.application.credentials).to receive(:cloudinary_api_secret!).and_return(api_secret)
  end

  it "returns the secure_url on success" do
    stub_request(:post, upload_url)
      .to_return(
        status: 200,
        body: JSON.generate("secure_url" => "https://res.cloudinary.com/testcloud/image/upload/recipe.jpg"),
        headers: { "Content-Type" => "application/json" }
      )

    result = described_class.call(image_bytes, media_type: media_type)

    expect(result).to eq("https://res.cloudinary.com/testcloud/image/upload/recipe.jpg")
  end

  it "sends api_key, timestamp, and signature in the request body" do
    stub = stub_request(:post, upload_url)
      .to_return(
        status: 200,
        body: JSON.generate("secure_url" => "https://res.cloudinary.com/testcloud/image/upload/recipe.jpg"),
        headers: { "Content-Type" => "application/json" }
      )

    described_class.call(image_bytes, media_type: media_type)

    expect(stub).to have_been_requested
    expect(WebMock).to have_requested(:post, upload_url)
      .with { |req| req.body.include?("api_key=key123") }
  end

  it "raises Error on non-200 response" do
    stub_request(:post, upload_url).to_return(status: 400, body: '{"error":{"message":"bad"}}')

    expect { described_class.call(image_bytes, media_type: media_type) }
      .to raise_error(CloudinaryUploader::Error, /400/)
  end

  it "raises Error on network failure" do
    stub_request(:post, upload_url).to_raise(Faraday::ConnectionFailed.new("refused"))

    expect { described_class.call(image_bytes, media_type: media_type) }
      .to raise_error(CloudinaryUploader::Error)
  end
end
