# frozen_string_literal: true

require_relative '../info'

module JekyllIS::Images::Assets

  def register context
    site = context.site
    assets_path = "#{ JekyllIS::Images::Info::PATH }/assets"
    assets = Dir[ '**/*', base: assets_path ].select { File.file?("#{ assets_path }/#{ it }") }
    assets.each do |file|
      extension = File.extname file
      target = file.sub(/#{ extension }$/, "-#{ JekyllIS::Images::Info::VERSION }#{ extension }")
      site.static_files << IS::StaticFile::new(site, '/', target, source: "#{ assets_path }/#{ file }")
    end
    site.static_files << CSS::floats(context)
    site.static_files << CSS::loader(context)
    site.static_files <<  JS::loader(context)
  end

  def stuff context
    <<~HTML
      <!-- jekyll-is-images plugin stuff -->
      <link rel="stylesheet" href="#{ CSS::loader(context).url }" />
      <script type="module" src="#{ JS::loader(context).url }"></script>
      <!-- end of jekyll-is-images stuff -->
    HTML
  end

  extend self

end
