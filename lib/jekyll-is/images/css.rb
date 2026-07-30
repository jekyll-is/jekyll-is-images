# frozen_string_literal: true

require_relative 'info'

module JekyllIS::Images::CSS

  # @param [JekyllIS::Images::Context] context
  # @return [String]
  def generate context
    max_width = context['max_text_width'] || 1920
    min_width = context['min_text_width'] || 200
    max_number = ((max_width - min_width).to_f / 50).ceil
    start = <<~CSS
      .__is_images__right, .__is_images__left {
        float: none;
        margin: 0px auto;
      }

      :has(> .__is_images__right, > .__is_images__left) {
        container-type: inline-size;
      }
    CSS
    main = (1 .. max_number).map do |num|
      item_width = 50 * num
      container_width = item_width + min_width
      smaller = (1 .. num).map { ".__is_images_width_#{ it * 50 }" }.join(",\n  ")
      <<~CSS
        @container (#{ container_width }px <= width < #{ container_width + 50 }px) {

          #{ smaller } {

            &.__is_images__right {
              float: right;
              margin-top: calc(0px - var(--is-images-up, 0px));
              margin-right: calc(0px - min(var(--is-images-shift, 0px), calc(50vw - 50cqw)));
            }

            &.__is_images__left {
              float: left;
              margin-top: calc(0px - var(--is-images-up, 0px));
              margin-left: calc(0px - min(var(--is-images-shift, 0px), calc(50vw - 50cqw)));
            }
          }
        }
      CSS
    end.join("\n\n")
    "#{ start }\n\n#{ main }"
  end

  extend self

end
