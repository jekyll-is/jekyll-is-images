# frozen_string_literal: true

require_relative 'value'

class JekyllIS::Images::Kramdown::Figure < JekyllIS::Images::Kramdown::Value

  def type = :is_figure

  def category = :block

  attr_reader :children

  def initialize context
    super(context)
    @children = []
  end

  def gallery?
    @children.size > 1
  end

  attr_reader :caption

  def apply element
    super(element)
    @caption = @attrs.delete('caption')
    element.children.each do |child|
      if [ :a, :img ].include?(child.type)
        image = JekyllIS::Images::Kramdown::Image::new @context, figure: self
        image.apply child
        @children << image
      end
    end
    if @children.size == 1
      image = @children.first
      @caption ||= image.caption
      @attrs = image.attrs.merge(@attrs)
      # «Крадём» классы и флаги.
      @flags.merge image.flags
      image.flags.clear
      @classes.merge image.classes
      image.classes.clear
    end
  end

end
