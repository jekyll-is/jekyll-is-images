# frozen_string_literal: true

require 'jekyll'

require_relative '../info'
require_relative 'config'

module JekyllIS::Images::Error

  include JekyllIS::Images::Config

  ABORT_KEY = 'abort_on_error'

  def abort_on_error?
    @abort_on_error ||= config(ABORT_KEY)
  end

  def error message
    if abort_on_error?
      Jekyll::logger.abort_with caller_locations(1, 1).first.to_s, message
    else
      Jekyll::logger.error caller_locations(1, 1).first.to_s, message
    end
  end

  def warning message
    Jekyll::logger.warn caller_locations(1, 1).first.to_s, message
  end

end
