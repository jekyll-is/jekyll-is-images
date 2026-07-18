# frozen_string_literal: true

require 'is-kramdown-hooked'

require_relative 'error'
require_relative 'objects'
require_relative 'converters'

module JekyllIS; end
module JekyllIS::Images; end

module JekyllIS::Images::Hooks

  class Processor

    include JekyllIS::Images::Error

    def initialize site, page, root
      @site = site
      @page = page
      @root = root
    end

    def process
      process_element @root
    end

    private

    def image_element? element
      element.type == :img || element.type == :a && element.children&.size == 1 && element.children&.first&.type == :img
    end

    def image_container? element
      element.children&.size > 0 && element.children.all? { image_element? it }
    end

    def process_p element, parent: nil, index: nil
      if image_container?(element)
        figure = JekyllIS::Images::Figure::new @site, @page
        figure.apply_p element
        replacement = figure.to_element
        if parent && parent.children
          if index
            parent.children[index] = replacement
          else
            error "Child not found: #{ element.inspect } in #{ parent.inspect }"
          end
        else
          warning "Orphan container: #{ element.inspect }"
        end
        replacement
      else
        element
      end
    end

    def process_a element, parent: nil, index: nil
      if image_element?(element)
        image = JekyllIS::Images::Image::new @site, @page
        image.apply_a element
        replacement = image.to_element
        if parent && parent.children
          if index
            parent.children[index] = replacement
          else
            error "Child not found: #{ element.inspect } in #{ parent.inspect }"
          end
        else
          warning "Orphan anchor: #{ element.inspect }"
        end
        replacement
      else
        element
      end
    end

    def process_img element, parent: nil, index: nil
      if image_element?(element)
        image = JekyllIS::Images::Image::new @site, @page
        image.apply_img element
        replacement = image.to_element
        if parent && parent.children
          if index
            parent.children[index] = replacement
          else
            error "Child not found: #{ element.inspect } in #{ parent.inspect }"
          end
        else
          warning "Orphan anchor: #{ element.inspect }"
        end
        replacement
      else
        element
      end
    end

    def process_element element, parent: nil, index: nil
      case element.type
      when :p
        process_p element, parent: parent, index: index
      when :a
        process_a element, parent: parent, index: index
      when :img
        process_img element, parent: parent, index: index
      else
        if element.children
          element.children.each_with_index do |child, index|
            process_element child, parent: element, index: index
          end
        end
        element
      end
    end

  end

  class << self

    def init_hooks site
      Jekyll::Hooks::register [ :pages, :documents ], :pre_render do |page, payload|
        page.data['img_hook'] = Kramdown::Parser::ISKram::register_post_parse_hook do |parser|
          processor = Processor::new site, page, parser.root
          processor.process
        end
      end
      Jekyll::Hooks::register [ :pages, :documents ], :post_render do |page, payload|
        hook = page.data['img_hook']
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
