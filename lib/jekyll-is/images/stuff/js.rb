# frozen_string_literal: true

require 'is-static-files'

require_relative 'assets'

module JekyllIS::Images::Assets::JS

  def loader context
    @loader ||= generate_loader(context)
  end

  private

  def generate_loader context
    content = <<~JS
      import { initSlidesWheel, initSlidesNavBar, initViewBox } from '/js/plugins/is-images-#{ JekyllIS::Images::Info::VERSION }.js';

      document.addEventListener('DOMContentLoaded', () => {
        initSlidesWheel();
        initSlidesNavBar();
        initViewBox();
      });
    JS
    IS::StaticFile::new context.site, '/', "/js/is-images-#{ JekyllIS::Images::Info::VERSION }.js", content: content
  end

  extend self

end
