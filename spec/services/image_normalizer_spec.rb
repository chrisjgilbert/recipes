require "rails_helper"

RSpec.describe ImageNormalizer do
  def jpeg_bytes
    "\xFF\xD8\xFF\xE0".b + ("padding" * 4).b
  end

  def png_bytes
    "\x89PNG\r\n\x1A\n".b + ("padding" * 4).b
  end

  def heic_bytes
    "\x00\x00\x00\x20ftypheic".b + ("payload" * 8).b
  end

  it "passes JPEG through unchanged" do
    bytes, media = described_class.call(StringIO.new(jpeg_bytes))
    expect(media).to eq("image/jpeg")
    expect(bytes).to eq(jpeg_bytes)
  end

  it "passes PNG through unchanged" do
    _bytes, media = described_class.call(StringIO.new(png_bytes))
    expect(media).to eq("image/png")
  end

  it "falls back to content type when magic bytes are unrecognized" do
    bytes, media = described_class.call(StringIO.new("xxxx"), original_content_type: "image/webp")
    expect(media).to eq("image/webp")
    expect(bytes).to eq("xxxx".b)
  end

  it "rejects unsupported types" do
    expect {
      described_class.call(StringIO.new("BM" + "x" * 10), original_content_type: "image/bmp")
    }.to raise_error(ImageNormalizer::Error, /unsupported/i)
  end

  it "rejects empty input" do
    expect { described_class.call(StringIO.new("")) }
      .to raise_error(ImageNormalizer::Error, /empty/i)
  end

  it "converts HEIC by shelling out to vips" do
    expect(Open3).to receive(:capture3) do |*cmd, **|
      expect(cmd.first).to eq("vips")
      expect(cmd[1]).to eq("copy")
      File.binwrite(cmd[3], jpeg_bytes)
      ["", "", instance_double(Process::Status, success?: true, exitstatus: 0)]
    end

    bytes, media = described_class.call(StringIO.new(heic_bytes))
    expect(media).to eq("image/jpeg")
    expect(bytes).to eq(jpeg_bytes)
  end

  it "raises a clear error when vips is not installed" do
    allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

    expect { described_class.call(StringIO.new(heic_bytes)) }
      .to raise_error(ImageNormalizer::Error, /libvips/i)
  end

  it "raises when vips exits non-zero" do
    allow(Open3).to receive(:capture3)
      .and_return(["", "bad heic", instance_double(Process::Status, success?: false, exitstatus: 1)])

    expect { described_class.call(StringIO.new(heic_bytes)) }
      .to raise_error(ImageNormalizer::Error, /conversion failed/i)
  end
end
