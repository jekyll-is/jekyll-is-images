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

module JekyllIS::Images::Image::Cache

  DIGITS_KEY = "cache_digits"
  GEN = 'gen'
  TMP = 'tmp'

  private_constant :DIGITS_KEY, :GEN, :TMP

  # @param [JekyllIS::Images::Context] context
  # @param [String] digest
  # @param [String] format
  # @yield Image generation code.
  # @yieldparam [String] target Path for result (full).
  # @yieldreturn [void] ignored
  # @return [JekyllIS::Images::Image::Info]
  def static_info context, digest, format, &block
    full, path, url = cached_file(context, GEN, digest, '.' + format, &block)
    raise "File not found: #{ path.inspect }" unless full && File.file?(full)
    second = if path.start_with?('/')
      path[1..]
    else
      "/#{ path }"
    end
    static = context.site.static_files.find { it.relative_path == path || it.relative_path == second || it.path == path || it.path == second }
    unless static
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

  # @api private
  # @param [JekyllIS::Images::Context] context
  # @param [String] digest
  # @param [String] suffix
  # @yield File creation
  # @yieldparam [String] target Path for resulting file
  # @yieldreturn [void] ignored
  # @return [Array<String, String, String>] full path, inner path, target url
  def cached_file context, prefix, digest, suffix
    splitted = split_digest context, digest
    path = "#{ context.cache_path }/#{ prefix }/#{ splitted }#{ suffix }"
    url = "/#{ context.target_path_prefix }/#{ splitted }#{ suffix }"
    full = context.site.in_source_dir path
    unless File.file?(full)
      FileUtils.mkdir_p File.dirname(full)
      yield full if block_given?
    end
    if File.file?(full)
      [ full, path, url ]
    else
      [  nil,  nil, nil ]
    end
  end

  # @param [JekyllIS::Images::Context] context
  # @param [String] digest
  # @param [String] suffix
  # @yield Image generation code.
  # @yieldparam [String] target Path for result (full).
  # @yieldreturn [void] ignored
  # @return [MiniMagick::Image]
  def magick_image context, digest, suffix, &block
    full, path, _ = cached_file(context, TMP, digest, suffix, &block)
    raise "File not found: #{ path.inspect }" unless full && File.file?(full)
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
    sha256.hexdigest.tr('ad', 'ot')          # Чтобы нигде не случилось участка пути /ad/, который режут баннерорезки...
  end

  # @api private
  # @param [JekyllIS::Images::Context] context
  # @return [void]
  def restore_static_files context
    cache_path = context.site.in_source_dir context.cache_path
    generated_path = "#{ cache_path }/#{ GEN }"
    if File.directory?(generated_path)
      cache_files = Dir[ '**/*', base: generated_path ].select { File.file? "#{ generated_path }/#{ it }" }
      cache_files.each do |file|
        url = "/#{ context.target_path_prefix }/#{ file }"
        context.site.static_files << IS::StaticFile::new(context.site, '/', url, source: "#{ context.cache_path }/#{ GEN }/#{ file }")
      end
    end
  end

  # @api private
  # @param [JekyllIS::Images::Context] context
  # @return [void]
  def clean_unused_files context
    cache_path = context.site.in_source_dir context.cache_path
    cache_files = Dir[ "#{ cache_path }/**/*" ].select { File.file? it }
    static_files = context.site.static_files.map(&:path).select { it.is_a?(String) }.map { it.start_with?('/') ? it : context.site.in_source_dir(it) }
    orphan_files = cache_files - static_files
    File.delete(*orphan_files)
    Jekyll::logger.info 'jekyll-is-images', "Cleanup: #{ orphan_files.size } files deleted."
    Dir[ "#{ cache_path }/**/*" ].select { File.directory? it }.reverse_each do |dir|
      Dir.rmdir dir if (Dir.entries(dir) - %w[. ..]).empty?
    end
  end

  private

  def jekyll_cache
    @jekyll_cache ||= Jekyll::Cache::new(JekyllIS::Images::Info::NAME)
  end

  def split_digest context, digest
    "#{ digest[0..1] }/#{ digest[2..3] }/#{ digest[4..(context.config(DIGITS_KEY).to_i + 3)] }"
  end

  extend self

end
