# frozen_string_literal: true

module JekyllIS; end
module JekyllIS::Images; end

module JekyllIS::Images::Error

  private

  def abort_on_error?
    @abort_on_error ||= @site.config.dig("is_images", "abort_on_error")
  end

  def error(message)
    if abort_on_error?
      Jekyll::logger.abort_with self.class.name, message
    else
      Jekyll::logger.error self.class.name, message
    end
  end

  def warning(message)
    Jekyll::logger.warn self.class.name, message
  end

end
