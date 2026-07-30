# frozen_string_literal: true

require_relative 'info'
require_relative 'context/config'
require_relative 'context/error'

class JekyllIS::Images::Context

  include JekyllIS::Images::Context::Config
  include JekyllIS::Images::Context::Error

  attr_reader :site, :page

  def initialize site, page
    @site = site
    @page = page
  end

  def markdown
    @markdown ||= @site.find_converter_instance(Jekyll::Converters::Markdown)
  end

  class << self

    def [] site, page
      new(site, page)
    end

  end

end
