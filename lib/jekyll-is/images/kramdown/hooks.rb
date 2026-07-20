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

Jekyll::Hooks::register :site, :after_init do |site|
  if site.config.dig('kramdown', 'input') == 'ISKram'
    JekyllIS::Images::Hooks::init_hooks site
  else
    Jekyll::logger.error 'jekyll-is-images', 'ISKram parser is not initialized: JekyllIS::Images features can not be enabled!'
  end
end
