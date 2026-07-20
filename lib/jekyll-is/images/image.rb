# frozen_string_literal: true

require_relative 'image/data'
require_relative 'image/transform'

JekyllIS::Images::Image.extend JekyllIS::Images::Image::Transform
