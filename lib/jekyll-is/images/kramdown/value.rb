# frozen_string_literal: true

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

end
