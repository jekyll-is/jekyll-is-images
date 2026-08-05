# frozen_string_literal: true

require 'mini_magick'

require_relative 'data'

module JekyllIS::Images::Image::Magick

  # @param [String] target
  # @param [String] source
  # @param [String] format
  # @param [JekyllIS::Context::Config::Options] options
  # @param [String, nil] crop
  # @param [String, nil] resize
  # @return [void]
  def magick_convert target, source, format:, options:, crop: nil, resize: nil
    is_svg = File.extname(source).downcase == '.svg'
    MiniMagick::convert do |cmd|
      if is_svg
        cmd << '-density' << '300'
        cmd << '-background' << 'none'
      end
      cmd << source
      cmd.crop crop if crop
      cmd.resize resize if resize
      cmd.strip
      cmd.colorspace 'sRGB'
      cmd.quality options.quality if options && options.quality
      options&.defines&.each do |value|
        cmd.define value
      end
      cmd.format format
      cmd << "#{ format }:#{ target }"
    end
  end

  # @param [String] target
  # @param [String] format
  # @param [Integer] width
  # @param [Integer] height
  # @param [String, nil] background
  # @param [String, nil] foreground
  # @param [Boolean] canvas
  # @yield Additional code.
  # @yieldparam [MiniMagick::Tool] cmd
  # @yieldreturn [void] ignored
  # @return [void]
  def magick_generate target, format: 'png32', width:, height:, background: 'none', foreground: nil, canvas: true
    MiniMagick::convert do |cmd|
      cmd.background background if background
      cmd.fill foreground if foreground
      cmd.size "#{ width }x#{ height }"
      cmd << 'canvas:' if canvas
      yield cmd if block_given?
      cmd.format format
      cmd.alpha 'set'
      cmd << "#{ format }:#{ target }"
    end
  end

  extend self

end
