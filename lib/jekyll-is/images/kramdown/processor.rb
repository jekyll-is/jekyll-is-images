# frozen_string_literal: true

require_relative '../context'
require_relative 'image'
require_relative 'figure'

class JekyllIS::Images::Kramdown::Processor

  attr_reader :context

  def initialize site, page
    @context = JekyllIS::Images::Context[site, page]
  end

  def process root
    process_element root
  end

  private

  def image? element
    return false unless element && element.type == :img && element.attr['src']
    # Не все изображения нам нужно обрабатывать. В частности, если src начинается со слеша,
    #  конвертация не производится, и элемент img обрабатывается по умолчанию.
    # Тем не менее, нам может понадобиться, с одной стороны, использовать необрабатываемые
    #  изображения в галереях, или других figure, тогда следует явно указать положительное
    #  значение в атрибуте is-image. С другой стороны, мы можем проигнорировать обработку
    #  картинки с src, не начинающимся со слеша — тогда следует явно указать отрицательное
    #  значение в том же атрибуте.
    flag = element.attr['is-image']
    if element.attr['src'].start_with?('/')
      [ '1', 'true', 'yes', '+' ].include?(flag)
    else
      ![ '0', 'false', 'no', '-' ].include?(flag)
    end
  end

  def anchor? element
    # Нас интересуют не все якоря, а только оборачивающие единственное изображение.
    element && element.type == :a && element.children && element.children.size == 1 && image?(element.children.first)
  end

  def blank? element
    element && element.type == :blank
  end

  def figure? element
    # В тег <figure> превращаются абзацы, содержащие только изображения.
    element && element.type == :p && element.children && element.children.count { image?(it) || anchor?(it) || blank?(it) } > 0
  end

  def process_element element, parent = nil, index = nil
    if figure?(element)
      value = JekyllIS::Images::Kramdown::Figure::new @context
      value.apply element
      parent.children[index] = value.to_kramdown
    elsif image?(element) || anchor?(element)
      value = JekyllIS::Images::Kramdown::Image::new @context
      value.apply element
      parent.children[index] = value.to_kramdown
    else
      if element.children
        element.children.each_with_index do |child, index|
          process_element child, element, index
        end
      end
    end
  end

end
