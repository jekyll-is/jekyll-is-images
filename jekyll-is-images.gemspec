# frozen_string_literal: true

require_relative 'lib/jekyll-is/images/info'

Gem::Specification.new do |s|

  s.name        =   JekyllIS::Images::Info::NAME
  s.version     =   JekyllIS::Images::Info::VERSION
  s.summary     =   JekyllIS::Images::Info::SUMMARY
  s.description =   JekyllIS::Images::Info::SUMMARY + '.'
  s.authors     = [ JekyllIS::Images::Info::AUTHOR  ]
  s.email       = [ JekyllIS::Images::Info::EMAIL   ]
  s.files       = Dir[ 'lib/**/*', 'assets/**/*', 'notes/**/*', 'README.md', 'LICENSE']
  s.homepage    =   JekyllIS::Images::Info::HOMEPAGE
  s.license     =   JekyllIS::Images::Info::LICENSE

  s.required_ruby_version = '~> 3.4'

  s.add_dependency "kramdown", "~> 2.5"
  s.add_dependency 'mini_magick', '~> 5.3.2'
  s.add_dependency 'nokogiri', '~> 1.19.4'
  s.add_dependency 'is-static-files', '~> 0.8.0'
  # s.add_dependency 'is-kramdown-hooked', '~> 0.8.6'
  s.add_dependency 'jekyll-is-hookdown', '~> 0.8.0.2'

  s.add_development_dependency 'rspec', '~> 3.13'
  s.add_development_dependency 'rake', '~> 13.3'
  s.add_development_dependency 'simplecov', '~> 1.1'
end
