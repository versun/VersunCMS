module Tools
  class Export
    require "zip"

    attr_reader :zip_path, :error_message

    def initialize
      @zip_path = nil
      @error_message = nil
    end

    def generate
      begin
        # Create temp directory for database backup
        temp_dir = Rails.root.join("storage", "backup", "temp")
        FileUtils.mkdir_p(temp_dir)

        # Get database configurations
        db_configs = Rails.configuration.database_configuration[Rails.env]
        Rails.logger.info "Database configs: #{db_configs.inspect}"

        # Convert to hash of configs if it's a single database config
        db_configs = { "primary" => db_configs } if db_configs.key?("database")

        temp_dbs = []

        # Process each database
        db_configs.each do |db_name, config|
          next unless config && config["database"]

          db_path = Rails.root.join(config["database"]).to_s
          db_file = File.basename(db_path)

          Rails.logger.info "Processing database #{db_name} at path: #{db_path}"

          # Skip if database file doesn't exist
          unless File.exist?(db_path)
            Rails.logger.warn "Database file not found: #{db_path}"
            next
          end

          temp_db = File.join(temp_dir, "#{db_name}_#{db_file}")

          # Use sqlite3 .backup command to create a consistent backup
          system("sqlite3", db_path, ".backup '#{temp_db}'")

          unless File.exist?(temp_db)
            Rails.logger.error "Failed to backup database #{db_name}"
            next
          end

          temp_dbs << { path: temp_db, file: db_file, name: db_name }
          Rails.logger.info "Backed up database #{db_name} to: #{temp_db}"
        end

        if temp_dbs.empty?
          raise "No valid database files found to backup"
        end

        # Create zip file
        @zip_path = File.join(temp_dir, "backup.zip")
        # Delete existing zip file if it exists
        FileUtils.rm_f(@zip_path) if File.exist?(@zip_path)

        Zip::File.open(@zip_path, Zip::File::CREATE) do |zipfile|
          temp_dbs.each do |db|
            Rails.logger.info "Adding to zip: #{db[:file]} from #{db[:path]}"
            # Store with database name prefix to avoid conflicts
            zip_path = "#{db[:name]}_#{db[:file]}"
            zipfile.add(zip_path, db[:path])
          end
        end

        ActivityLog.create!(
          action: "export",
          target: "backup",
          level: :info,
          description: "Successfully created backup archive with #{temp_dbs.size} databases"
        )

        true
      rescue StandardError => e
        @error_message = e.message
        Rails.logger.error "Export error: #{e.message}\n#{e.backtrace.join("\n")}"
        ActivityLog.create!(
          action: "export",
          target: "backup",
          level: :error,
          description: "Failed to create backup: #{e.message}"
        )
        false
      ensure
        # Clean up temporary database files
        temp_dbs&.each do |db|
          FileUtils.rm_f(db[:path]) if db[:path]
        end
      end
    end
  end
end
