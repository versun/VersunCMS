class RssImportJob < ApplicationJob
  queue_as :default

  def perform(url, import_images)
    Tools::RssImport.new(url, import_images).import_data
  end
end
