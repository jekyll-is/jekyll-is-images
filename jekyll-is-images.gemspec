Gem::Specification.new do |s|
  s.name = "jekyll-is-images"
  s.version = "0.8.0"
  s.summary = "Images processing for Jekyll"
  s.description = "Images processing for Jekyll."
  s.authors = ["Ivan Shikhalev"]
  s.email = ["shikhalev@gmail.com"]
  s.files = Dir["lib/**/*", "README.md", "LICENSE"]
  s.homepage = "https://github.com/jekyll-is/jekyll-is-images"
  s.license = "LGPL-3.0-or-later"

  s.required_ruby_version = "~> 3.4"

  s.add_dependency "kramdown", "~> 2.5"
  s.add_dependency 'mini_magick', '~> 5.3.2'
  s.add_dependency 'nokogiri', '~> 1.19.4'
  # s.add_dependency 'is-kramdown-hooked', path: '../is-kramdown-hooked'

  s.add_development_dependency "rspec", "~> 3.13"
  s.add_development_dependency "rake", "~> 13.3"
  s.add_development_dependency "simplecov", "~> 1.0.0"
end
