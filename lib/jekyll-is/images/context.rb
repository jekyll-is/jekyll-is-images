# frozen_string_literal: true

require_relative 'info'
require_relative 'context/config'
require_relative 'context/error'

class JekyllIS::Images::Context

  include JekyllIS::Images::Config
  include JekyllIS::Images::Error

  attr_reader :site, :page

  def initialize site, page
    @site = site
    @page = page
  end

  class << self

    def [] site, page
      @contexts ||= {}
      @contexts[site] ||= {}
      @contexts[site][page] ||= new(site, page)
    end

    private :new

  end

end
