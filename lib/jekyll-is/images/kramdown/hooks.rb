# frozen_string_literal: true

require 'is-kramdown-hooked'

require_relative 'processor'

module JekyllIS::Images::Kramdown::Hooks

  class << self

    HOOK_PAGE_VAR = '__is_images_hook'

    def init_hooks site
      Jekyll::Hooks::register [ :pages, :documents ], :pre_render do |page, _|
        page.data[HOOK_PAGE_VAR] = Kramdown::Parser::ISKram::register_post_parse_hook do |parser|
          processor = JekyllIS::Images::Kramdown::Processor::new site, page
          processor.process parser.root
        end
      end
      Jekyll::Hooks::register [ :pages, :documents ], :post_render do |page, _|
        hook = page.data[HOOK_PAGE_VAR]
        Kramdown::Parser::ISKram::unregister_post_parse_hook hook if hook
      end
    end

  end

end

module JekyllIS::Images

  class << self

    attr_accessor :cached_environment

  end

end

Jekyll::Hooks::register :site, :after_init do |site|
  jekyll_cache = site.in_source_dir(".jekyll-cache/Jekyll/Cache/Jekyll--Converters--Markdown")
  JekyllIS::Images.cached_environment = File.directory?(jekyll_cache) # && !(Dir.entries(jekyll_cache) - %w[. ..]).empty?
  # Jekyll::logger.warn Dir.entries(jekyll_cache).inspect
  if site.config.dig('kramdown', 'input') == 'ISKram'
    JekyllIS::Images::Kramdown::Hooks::init_hooks site
  else
    Jekyll::logger.error 'jekyll-is-images', 'ISKram parser is not initialized: JekyllIS::Images features can not be enabled!'
  end
end

Jekyll::Hooks::register :site, :after_reset do |site|
  if File.directory?(site.in_source_dir('.jekyll-cache/Jekyll/Cache/Jekyll--Converters--Markdown'))
    context = JekyllIS::Images::Context[site, nil]
    cache_path = site.in_source_dir context.cache_path
    context.warning cache_path.inspect
    if File.directory?("#{ cache_path }/processed")
      cache_files = Dir[ '**/*', base: "#{ cache_path }/processed" ].select { File.file?("#{cache_path}/processed/#{it}") }
      context.warning cache_files.inspect
      cache_files.each do |file|
        site.static_files << IS::StaticFile::new(site, '/', "/img/#{file}", source: "#{context.cache_path}/processed/#{file}")
      end
    end
  end
end

Jekyll::Hooks::register :site, :post_write do |site|
  is_live = site.config['watch'] || site.config['serving'] || site.incremental? || JekyllIS::Images.cached_environment
  context = JekyllIS::Images::Context[site, nil]
  cache_path = site.in_source_dir context.cache_path
  if !is_live && File.directory?(cache_path)
    cache_files = Dir[ "#{ cache_path }/**/*" ].select { File.file?(it) }
    static_files = site.static_files.map(&:path).map { it.start_with?('/') ? it : site.in_source_dir(it) }
    orphan_files = cache_files - static_files
    File.delete *orphan_files
    Jekyll::logger.info 'jekyll-is-images', "Cleanup: #{ orphan_files.size } files deleted."

    Dir[ "#{cache_path}/**/*" ].select { File.directory?(it) }.reverse_each do |dir|
      Dir.rmdir(dir) if (Dir.entries(dir) - %w[. ..]).empty?
    end
  end
end
