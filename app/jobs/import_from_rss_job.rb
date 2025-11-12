class ImportFromRssJob < ApplicationJob
  queue_as :default

  def perform(url, import_images)
    ImportRSS.new(url, import_images).import_data
  end
end
