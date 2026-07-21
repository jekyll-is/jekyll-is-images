# frozen_string_literal: true

require_relative '../info'

module JekyllIS::Images::Config

  DEFAULTS = {
    'abort_on_error' => true,
    'target_prefix' => 'img',
    'cache_path' => '.is-images-cache',
    'cache_digits' => 8,
    'default_link' => 'view',
    'caption_position' => 'bottom',
    'formats' => {
      'svg' => 'svg',
      'jpeg' => 'avif',
      'avif' => 'avif',
      'default' => 'webp'
    },
    'options' => {
      'jpeg' => {
        'quality' => '90'
      },
      'webp' => {
        'quality' => '80',
        'method' => '6',
        'progressive' => 'true',
        'alpha_compression' => '1'
      },
      'avif' => {
        'quality' => '70',
        'speed' => '1',
        'chroma_subsampling' => '4:2:0'
      }
    },
    'gallery' => {
      'modes' => 'grid,slides',
      'caption_position' => 'top'
    }
  }.freeze

  CONFIG_KEY = 'is_images'

  FORMATS_KEY = 'formats'
  OPTIONS_KEY = 'options'

  TARGET_PREFIX_KEY = 'target_prefix'
  CACHE_PATH_KEY = 'cache_path'

  def config *path, check_default: false

    value = @page&.data&.dig CONFIG_KEY, *path
    return value if value
    value = @site&.config&.dig CONFIG_KEY, *path
    return value if value

    default = path.dup
    default[-1] = 'default'
    if check_default
      value = @page&.data.dig CONFIG_KEY, *default
      return value if value
      value = @site&.config.dig CONFIG_KEY, *default
      return value if value
    end

    value = DEFAULTS.dig *path
    return value if value
    if check_default
      value = DEFAULTS.dig *default
      return value if value
    end

    nil
  end

  Options = Data::define :quality, :defines

  DEFINE_KEYS = {
    'avif' => 'heic'
  }

  def options format, attrs = {}

    default_values = DEFAULTS.dig(OPTIONS_KEY, format) || {}
    page_values = @page&.data&.dig(CONFIG_KEY, OPTIONS_KEY, format) || {}
    site_values = @site&.config&.dig(CONFIG_KEY, OPTIONS_KEY, format) || {}
    config_values = {}
    config_values.merge! default_values
    config_values.merge! site_values
    config_values.merge! page_values

    quality = attrs['quality'] || config_values.delete('quality')

    defines = {}
    define_key = DEFINE_KEYS[format] || format
    config_values.each do |k, v|
      defines[define_key + ':' + k.tr('_', '-')] = v
    end
    attrs.each do |k, v|
      if k.start_with?(define_key + '-')
        defines[k.sub(define_key + '-', define_key + ':')] = v
      end
    end

    Options::new quality, defines.map { |k, v| "#{k}=#{v}" }
  end

  def target_path_prefix
    @target_path_prefix ||= config(TARGET_PREFIX_KEY)
  end

  def cache_path
    @cache_path ||= config(CACHE_PATH_KEY)
  end

  def detect_format source
    source_format = source&.split('#')&.first&.split('?')&.first&.split('.')&.last&.downcase
    source_format = 'jpeg' if source_format == 'jpg'
    source_format = 'tiff' if source_format == 'tif'
    config(FORMATS_KEY, source_format, check_default: true) || source_format
  end

end
