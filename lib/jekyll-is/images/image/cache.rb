# frozen_string_literal: true

require 'fileutils'
require 'digest'
require 'json'
require 'jekyll'
require 'mini_magick'
require 'is-static-files'

require_relative '../info'
require_relative '../context'
require_relative 'data'

module JekyllIS::Images::Cache

  DIGITS_KEY = "cache_digits"

  class << self

    # @param [JekyllIS::Images::Context] context
    # @param [String] digest
    # @param [String] format
    # @yield Image generation code.
    # @yieldparam [String] target Path for result (full).
    # @yieldreturn [void] ignored
    # @return [JekyllIS::Images::Image::Info]
    def static_info context, digest, format
      splitted = split_digest context, digest
      path = "#{ context.cache_path }/gen/#{ splitted }.#{ format }"
      full = context.site.in_source_dir path
      unless File.file?(full)
        FileUtils.mkdir_p File.dirname(full)
        yield full if block_given?
      end
      raise "File not found: #{ path.inspect }" unless File.file?(full)
      second = if path.start_with?('/')
        path[1..]
      else
        "/#{ path }"
      end
      static = context.site.static_files.find { it.relative_path == path || it.relative_path == second || it.path == path || it.path == second }
      unless static
        url = "/#{ context.target_path_prefix }/#{ splitted }.#{ format }"
        static = IS::StaticFile::new context.site, '/', url, source: path
        context.site.static_files << static
      end
      props = jekyll_cache.getset digest do
        image = MiniMagick::Image::open full
        result = { width: image.width&.to_i, height: image.height&.to_i }
        image&.destroy!
        result
      end
      JekyllIS::Images::Image::Info[static.url, props[:width], (props[:width] && props[:height] ? props[:width].to_r / props[:height].to_r : nil)]
    end

    # @param [JekyllIS::Images::Context] context
    # @param [String] digest
    # @param [String] suffix
    # @yield Image generation code.
    # @yieldparam [String] target Path for result (full).
    # @yieldreturn [void] ignored
    # @return [MiniMagick::Image]
    def magick_image context, digest, suffix
      splitted = split_digest context, digest
      path = "#{ context.cache_path }/tmp/#{ splitted }-#{ suffix }"
      full = context.site.in_source_dir path
      unless File.file?(full)
        FileUtils.mkdir_p File.dirname(full)
        yield full if block_given?
      end
      raise "File not found: #{ path.inspect }" unless File.file?(full)
      MiniMagick::Image::open full
    end

    # @param [JekyllIS::Images::Context] context
    # @param [String, nil] source
    # @param [Hash] params
    # @return [String]
    def source_digest context, source, **params
      sha256 = Digest::SHA256::new
      sha256.update source if source
      unless source.nil? || source.empty? || source.start_with?('http://') || source.start_with?('https://')
        full = context.site.in_source_dir source
        File::open full, 'rb' do |file|
          while chunk = file.read(65536)
            sha256.update chunk
          end
        end
      end
      sha256.update JSON.generate(params, sort_keys: true)
      sha256.hexdigest
    end

    private

    def jekyll_cache
      @jekyll_cache ||= Jekyll::Cache::new(JekyllIS::Images::Info::NAME)
    end

    def split_digest context, digest
      "#{ digest[0..1] }/#{ digest[2..3] }/#{ digest[4..(context.config(DIGITS_KEY).to_i + 3)] }"
    end

  end

end
