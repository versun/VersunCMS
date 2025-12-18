namespace :static do
  desc "Generate all static files (HTML, images, assets)"
  task generate: :environment do
    puts "Starting full static site generation..."
    start_time = Time.current

    # Step 1: Precompile assets (CSS, JS)
    puts "\n[1/2] Precompiling assets..."
    Rake::Task["assets:precompile"].invoke

    # Step 2: Generate HTML pages, export images, and copy user static files
    puts "\n[2/2] Generating HTML pages and exporting images..."
    StaticGenerator.new.generate_all

    elapsed = Time.current - start_time
    puts "\n✓ Static site generation completed in #{elapsed.round(2)} seconds"
    puts "  Output directory: #{Rails.root.join('public')}"
  end

  desc "Generate HTML pages only (without asset precompilation)"
  task html_only: :environment do
    puts "Starting HTML generation..."
    start_time = Time.current

    StaticGenerator.new.generate_all

    elapsed = Time.current - start_time
    puts "HTML generation completed in #{elapsed.round(2)} seconds"
  end

  desc "Generate only index pages"
  task index: :environment do
    puts "Generating index pages..."
    StaticGenerator.new.generate_index_pages
    puts "Done!"
  end

  desc "Generate only article pages"
  task articles: :environment do
    puts "Generating article pages..."
    StaticGenerator.new.generate_all_articles
    puts "Done!"
  end

  desc "Generate only static pages"
  task pages: :environment do
    puts "Generating static pages..."
    StaticGenerator.new.generate_all_pages
    puts "Done!"
  end

  desc "Generate only tag pages"
  task tags: :environment do
    puts "Generating tag pages..."
    StaticGenerator.new.generate_tags_index
    StaticGenerator.new.generate_all_tag_pages
    puts "Done!"
  end

  desc "Generate RSS feed"
  task feed: :environment do
    puts "Generating RSS feed..."
    StaticGenerator.new.generate_feed
    puts "Done!"
  end

  desc "Generate sitemap"
  task sitemap: :environment do
    puts "Generating sitemap..."
    StaticGenerator.new.generate_sitemap
    puts "Done!"
  end

  desc "Clean generated static files"
  task clean: :environment do
    puts "Cleaning static files..."
    StaticGenerator.new.clean_generated_files
    puts "Clean complete!"
  end

  desc "Clean all generated files including assets"
  task clean_all: :environment do
    Rake::Task["static:clean"].invoke
    Rake::Task["assets:clobber"].invoke
    puts "All generated files cleaned!"
  end

  desc "Export static site to a deployable package"
  task export: :environment do
    puts "Exporting static site..."

    # Generate all static files first
    Rake::Task["static:generate"].invoke

    export_dir = Rails.root.join("tmp", "static_export")
    FileUtils.rm_rf(export_dir)
    FileUtils.mkdir_p(export_dir)

    public_dir = Rails.root.join("public")
    exported = 0

    # Use shared deployable items list
    StaticGenerator.deployable_items.each do |item|
      source = public_dir.join(item)
      next unless File.exist?(source)

      dest = export_dir.join(item)
      File.directory?(source) ? FileUtils.cp_r(source, dest) : FileUtils.cp(source, dest)
      puts "  Exported: #{item}"
      exported += 1
    end

    puts "\n✓ Static site exported to: #{export_dir} (#{exported} items)"
    puts "  You can deploy this directory to any static hosting service."
  end
end
