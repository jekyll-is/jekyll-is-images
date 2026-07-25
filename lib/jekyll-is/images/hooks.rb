# frozen_string_literal: true

require 'is-kramdown-hooked'

require_relative 'kramdown/processor'

module JekyllIS::Images::Hooks

  class << self

    # @private
    HOOK_PAGE_VAR = '__is_images_hook'

    # @api private
    def init_hooks site

      Jekyll::Hooks::register [ :pages, :documents ], :pre_render do |page, _|
        if !page.data.dig('is_images', 'disable')
          page.data[HOOK_PAGE_VAR] = Kramdown::Parser::ISKram::register_post_parse_hook do |parser|
            processor = JekyllIS::Images::Kramdown::Processor::new site, page
            processor.process parser.root
          end
        end
      end

      Jekyll::Hooks::register [ :pages, :documents ], :post_render do |page, _|
        hook = page.data[HOOK_PAGE_VAR]
        Kramdown::Parser::ISKram::unregister_post_parse_hook hook if hook

        unless page.data.dig('is_images', 'disable')
          context = JekyllIS::Images::Context[site, page]
          # Следует использовать is_images.disable_auto_stuff для того, чтобы те же самые линки разместить
          #  самостоятельно в шаблонах. Просто не использовать их при включенном плагие в целом — не имеет
          #  смысла.
          unless context.config('disable_auto_stuff')
            assets = <<-HTML
              <!-- jekyll-is-images plugin stuff -->
              <link rel="stylesheet" href="/css/is-images.css" />
              <script type="module" src="/js/is-images.js"></script>
              <!-- end of jekyll-is-images stuff -->
            HTML

            page.output.sub! '</head>', "#{ assets }\n</head>"
          end
        end
      end

      Jekyll::Hooks::register :site, :after_reset do |site|
        context = JekyllIS::Images::Context[site, nil]
        if File.directory?(site.in_source_dir(".jekyll-cache/Jekyll/Cache/Jekyll--Converters--Markdown"))
          cache_path = site.in_source_dir context.cache_path
          if File.directory?("#{cache_path}/processed")
            cache_files = Dir[ '**/*', base: "#{ cache_path }/processed" ].select { File.file?("#{cache_path}/processed/#{ it }") }
            cache_files.each do |file|
              site.static_files << IS::StaticFile::new(site, '/', "/img/#{ file }", source: "#{ context.cache_path }/processed/#{ file }")
            end
          end
        end
        assets_path = "#{ JekyllIS::Images::Info::PATH }/assets"
        assets = Dir[ '**/*', base: assets_path ].select { File.file?("#{ assets_path }/#{ it }") }
        assets.each do |file|
          site.static_files << IS::StaticFile::new(site, '/', file, source: "#{ assets_path }/#{ file }")
        end
      end

      Jekyll::Hooks::register :site, :post_write do |site|
        context = JekyllIS::Images::Context[site, nil]
        is_live = site.config["watch"] || site.config["serving"] || site.incremental? || JekyllIS::Images.cached_environment
        cache_path = site.in_source_dir context.cache_path
        if !is_live && File.directory?(cache_path)
          cache_files = Dir["#{ cache_path }/**/*"].select { File.file?(it) }
          static_files = site.static_files.map(&:path).map { it.start_with?("/") ? it : site.in_source_dir(it) }
          orphan_files = cache_files - static_files
          File.delete(*orphan_files)
          Jekyll::logger.info "jekyll-is-images", "Cleanup: #{ orphan_files.size } files deleted."

          Dir["#{ cache_path }/**/*"].select { File.directory?(it) }.reverse_each do |dir|
            Dir.rmdir(dir) if (Dir.entries(dir) - %w[. ..]).empty?
          end
        end
      end

    end

  end

end

module JekyllIS::Images

  # @private
  HOOK_CONFIG_VAR = "__is_images_registered"

  class << self

    # @private
    attr_accessor :cached_environment

    # @private
    def allowed? site
      site.config.dig('kramdown', 'input') == 'ISKram'
    end

    # @private
    def disabled? site
      !!site.config.dig('is_images', 'disabled')
    end

  end

end

Jekyll::Hooks::register :site, :after_init do |site|
  if JekyllIS::Images::allowed?(site)
    next if JekyllIS::Images::disabled?(site)
    unless site.config[JekyllIS::Images::HOOK_CONFIG_VAR]
      jekyll_cache = site.in_source_dir('.jekyll-cache/Jekyll/Cache/Jekyll--Converters--Markdown')
      JekyllIS::Images.cached_environment = File.directory?(jekyll_cache)
      JekyllIS::Images::Hooks::init_hooks site
      site.config[JekyllIS::Images::HOOK_CONFIG_VAR] = true
    end
  else
    Jekyll::logger.error 'jekyll-is-images', 'ISKram parser is not initialized: JekyllIS::Images features can not be enabled!'
  end
end
