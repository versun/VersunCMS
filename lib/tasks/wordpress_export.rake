namespace :export do
  desc "Test WordPress export functionality"
  task test_wordpress: :environment do
    puts "Testing WordPress export functionality..."
    
    begin
      exporter = WordpressExport.new
      
      puts "1. Creating WXR document..."
      doc = exporter.send(:create_wxr_document)
      puts "   ✓ WXR document created successfully"
      
      puts "2. Adding site info..."
      exporter.send(:add_site_info, doc)
      puts "   ✓ Site info added"
      
      puts "3. Adding authors..."
      exporter.send(:add_authors, doc)
      puts "   ✓ Authors added"
      
      puts "4. Adding categories..."
      exporter.send(:add_categories, doc)
      puts "   ✓ Categories added"
      
      puts "5. Adding posts..."
      exporter.send(:add_posts, doc)
      puts "   ✓ Posts added"
      
      puts "6. Adding pages..."
      exporter.send(:add_pages, doc)
      puts "   ✓ Pages added"
      
      puts "7. Saving XML file..."
      exporter.send(:save_xml_file, doc)
      puts "   ✓ XML file saved to: #{exporter.export_path}"
      
      puts "8. Validating XML..."
      xml_content = File.read(exporter.export_path)
      parsed_doc = Nokogiri::XML(xml_content)
      
      if parsed_doc.errors.empty?
        puts "   ✓ XML is valid"
      else
        puts "   ✗ XML has errors"
        puts parsed_doc.errors
      end
      
      puts "\nWordPress export test completed successfully!"
      puts "Export file: #{exporter.export_path}"
      
      # 显示文件大小
      file_size = File.size(exporter.export_path)
      puts "File size: #{(file_size / 1024.0).round(2)} KB"
      
      # 显示前几个字符
      preview = File.read(exporter.export_path, 500)
      puts "\nFile preview (first 500 chars):"
      puts "-" * 50
      puts preview
      puts "-" * 50
      
    rescue => e
      puts "Error during test: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
  
  desc "Generate WordPress export file"
  task wordpress: :environment do
    puts "Starting WordPress export..."
    
    exporter = WordpressExport.new
    success = exporter.generate
    
    if success
      puts "✓ WordPress export completed successfully!"
      puts "Export file: #{exporter.export_path}"
      
      if exporter.export_path.to_s.end_with?('.zip')
        puts "This is a ZIP file containing the WXR XML and all attachments."
      else
        puts "This is the WXR XML file."
      end
    else
      puts "✗ WordPress export failed: #{exporter.error_message}"
    end
  end
end