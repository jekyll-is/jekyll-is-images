# frozen_string_literal: true

require 'set'
require 'kramdown'

require_relative '../info'

module JekyllIS::Images::Kramdown; end

class JekyllIS::Images::Kramdown::Value

  attr_reader :context

  def initialize context
    @context = context
  end

  def to_kramdown
    Kramdown::Element::new self.type, self, nil, category: self.category
  end

  def type
    raise NotImplementedError, 'Abstract method call'
  end

  def category
    raise NotImplementedError, 'Abstract method call'
  end

  def to_html
    raise NotImplementedError, 'Abstract method call'
  end

  def to_latex
    raise NotImplementedError, 'Abstract method call'
  end

  attr_reader :attrs, :flags, :id, :classes, :styles

  def apply element
    @attrs ||= {}
    @attrs.merge!(element.attr&.dup || {})
    @flags ||= Set::new
    @flags.merge(element.options&.dig(:ial, :refs) || [])
    @id ||= @attrs.delete('id')
    @classes ||= Set::new
    @classes.merge(@attrs.delete('class')&.split(' ') || [])
    @styles ||= {}
    @styles.merge!(@attrs.delete('style')&.split(';')&.map { it.split(':', 2) }&.to_h || {})
  end

end
