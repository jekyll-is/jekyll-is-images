# frozen_string_literal: true

require_relative 'info'
require_relative 'context/config'
require_relative 'context/error'

class JekyllIS::Images::Context

  include JekyllIS::Images::Context::Config
  include JekyllIS::Images::Context::Error

  # @return [Jekyll::Site]
  attr_reader :site

  # @return [Jekyll::Page]
  attr_reader :page

  # @param [Jekyll::Site] site
  # @param [Jekyll::Page] page
  def initialize site, page
    @site = site
    @page = page
  end

  # @return [Jekyll::Converters::Markdown]
  def markdown
    @markdown ||= @site.find_converter_instance(Jekyll::Converters::Markdown)
  end

  class << self

    # @param [Jekyll::Site] site
    # @param [Jekyll::Page] page
    # @return [Context]
    def [] site, page
      new(site, page)
    end

  end

end
