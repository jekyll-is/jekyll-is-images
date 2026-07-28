# frozen_string_literal: true

require_relative 'image/data'
require_relative 'image/transform'
require_relative 'image/seo'

JekyllIS::Images::Image.extend JekyllIS::Images::Image::Transform
JekyllIS::Images::Image.extend JekyllIS::Images::Image::SEO
