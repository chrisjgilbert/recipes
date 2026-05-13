class ImageNormalizer
  class Error < StandardError; end

  CLAUDE_MEDIA_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  HEIF_MEDIA_TYPES = %w[image/heic image/heif].freeze

  def self.call(io, original_content_type: nil)
    new.call(io, original_content_type: original_content_type)
  end

  def call(io, original_content_type: nil)
    bytes = read_bytes(io)
    raise Error, "Empty image" if bytes.empty?

    detected = detect_media_type(bytes) || original_content_type.to_s.downcase.presence

    if CLAUDE_MEDIA_TYPES.include?(detected)
      [bytes, detected]
    elsif HEIF_MEDIA_TYPES.include?(detected)
      [convert_heif_to_jpeg(bytes), "image/jpeg"]
    else
      raise Error, "Unsupported image type: #{detected || "unknown"}"
    end
  end

  private

  def read_bytes(io)
    if io.respond_to?(:read)
      io.rewind if io.respond_to?(:rewind)
      io.read.to_s.b
    else
      io.to_s.b
    end
  end

  def detect_media_type(bytes)
    return "image/jpeg" if bytes.start_with?("\xFF\xD8\xFF".b)
    return "image/png" if bytes.start_with?("\x89PNG\r\n\x1A\n".b)
    return "image/gif" if bytes.start_with?("GIF87a".b) || bytes.start_with?("GIF89a".b)

    if bytes.byteslice(0, 4) == "RIFF".b && bytes.byteslice(8, 4) == "WEBP".b
      return "image/webp"
    end

    if bytes.byteslice(4, 4) == "ftyp".b
      brand = bytes.byteslice(8, 4).to_s
      return "image/heic" if %w[heic heix heim heis hevc hevx].include?(brand)
      return "image/heif" if %w[mif1 msf1 heif].include?(brand)
    end

    nil
  end

  def convert_heif_to_jpeg(bytes)
    require "open3"
    require "tempfile"

    input = Tempfile.new(["heic-in", ".heic"], binmode: true)
    output = Tempfile.new(["heic-out", ".jpg"], binmode: true)
    begin
      input.write(bytes)
      input.flush

      _stdout, stderr, status = Open3.capture3("vips", "copy", input.path, output.path)
      unless status.success?
        raise Error, "HEIC conversion failed: #{stderr.to_s.strip.presence || "vips exited #{status.exitstatus}"}"
      end

      output.rewind
      converted = output.read
      raise Error, "HEIC conversion produced empty output" if converted.to_s.empty?
      converted
    ensure
      input.close!
      output.close!
    end
  rescue Errno::ENOENT
    raise Error, "HEIC conversion unavailable: libvips (vips) not installed"
  end
end
