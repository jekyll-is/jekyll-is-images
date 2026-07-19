# frozen_string_literal: true

require_relative 'info'
require_relative 'config'

module JekyllIS::Images::Error

  include JekyllIS::Images::Config

  private

  ABORT_KEY = 'abort_on_error'

  def abort_on_error?
    @abort_on_error ||= config(ABORT_KEY)
  end

  def error message
    if abort_on_error?
      Jekyll::logger.abort_with self.class.name, message
    else
      Jekyll::logger.error self.class.name, message
    end
  end

  def warning message
    Jekyll::logger.warn self.class.name, message
  end

end
