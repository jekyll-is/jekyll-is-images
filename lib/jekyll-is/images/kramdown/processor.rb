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
    element.type == :img
  end

  def anchor? element
    element.type == :a && element.children&.size == 1 && element.children&.first&.type == :img
  end

  def blank? element
    element.type == :blank
  end

  def figure? element
    element.type == :p && element.children&.all? { image?(it) || anchor?(it) || blank?(it) }
  end

  def process_element element, parent = nil, index = nil
    if figure?(element)
      value = JekyllIS::Images::Kramdown::Value::Figure::new @context
      value.apply element
      parent[index] = value.to_kramdown
    elsif image?(element) || anchor?(element)
      value = JekyllIS::Images::Kramdown::Value::Image::new @context
      value.apply element
      parent[index] = value.to_kramdown
    else
      if element.children
        element.children.each_with_index do |child, index|
          process_element child, element, index
        end
      end
    end
  end

end
