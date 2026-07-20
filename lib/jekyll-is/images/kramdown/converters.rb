# frozen_string_literal: true

require "kramdown"

class Kramdown::Converter::Html
  def convert_is_image(el, _opts)
    el.value&.to_html
  end

  def convert_is_figure(el, _opts)
    el.value&.to_html
  end
end

class Kramdown::Converter::Latex
  def convert_is_image(el, _opts)
    el.value&.to_latex
  end

  def convert_is_figure(el, _opts)
    el.value&.to_latex
  end
end
