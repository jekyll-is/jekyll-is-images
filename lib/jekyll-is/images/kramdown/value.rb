# frozen_string_literal: true

require 'set'
require 'kramdown'

require_relative '../info'

module JekyllIS::Images::Kramdown; end

class JekyllIS::Images::Kramdown::Value

  # @return [JekyllIS::Images::Context]
  attr_reader :context

  # @param [JekyllIS::Images::Context] context
  def initialize context
    @context = context
  end

  # @return [Kramdown::Element]
  def to_kramdown
    Kramdown::Element::new self.type, self, nil, category: self.category
  end

  # @return [Symbol]
  def type
    raise NotImplementedError, 'Abstract method call'
  end

  # @return [Symbol]
  def category
    raise NotImplementedError, 'Abstract method call'
  end

  # @return [String]
  def to_html
    raise NotImplementedError, 'Abstract method call'
  end

  # @return [String]
  def to_latex
    raise NotImplementedError, 'Abstract method call'
  end

  # @return [Hash<String => String>]
  attr_reader :attrs

  # @return [Set<String>]
  attr_reader :flags

  # @return [String]
  attr_reader :id

  # @return [Set<String>]
  attr_reader :classes

  # @return [Hash<String => String>]
  attr_reader :styles

  # @param [Kramdown::Element] element
  # @return [self]
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
    self
  end

end
