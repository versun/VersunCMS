module Tools
  class DbImport
    require "zip"

    attr_reader :error_message

    def initialize
      @error_message = nil
    end

    def restore(zip_path)
      begin
        # Create temp directory for database restore
        temp_dir = Rails.root.join("storage", "backup", "temp")
        FileUtils.mkdir_p(temp_dir)

        # Get database configurations
        db_configs = Rails.configuration.database_configuration[Rails.env]
        Rails.logger.info "Database configs: #{db_configs.inspect}"

        # Convert to hash of configs if it's a single database config
        db_configs = { "primary" => db_configs } if db_configs.key?("database")

        # Extract zip file
        Zip::File.open(zip_path) do |zip_file|
          zip_file.each do |entry|
            # Extract database name from filename (format: dbname_filename.sqlite3)
            db_name = entry.name.split("_").first
            config = db_configs[db_name]

            unless config && config["database"]
              Rails.logger.warn "No configuration found for database: #{db_name}"
              next
            end

            target_path = Rails.root.join(config["database"]).to_s
            temp_path = File.join(temp_dir, entry.name)

            Rails.logger.info "Extracting #{entry.name} to #{temp_path}"
            entry.extract(temp_path)

            # Check if target database file is writable
            unless File.writable?(File.dirname(target_path))
              raise "Target directory is not writable: #{File.dirname(target_path)}"
            end

            # Stop all database connections
            Rails.logger.info "Stopping all database connections for restore"
            ActiveRecord::Base.connection_pool.disconnect!
            ActiveRecord::Base.connection_handler.clear_all_connections!

            begin
              # Set appropriate permissions and replace the database file
              FileUtils.chmod(0666, temp_path)
              FileUtils.mv(temp_path, target_path)
              FileUtils.chmod(0666, target_path)
              Rails.logger.info "Restored database #{db_name} to #{target_path}"
            ensure
              # Reconnect to database
              ActiveRecord::Base.establish_connection
              Rails.logger.info "Reestablished database connection"
            end
          end
        end

        ActivityLog.create!(
          action: "import",
          target: "backup",
          level: :info,
          description: "Successfully restored databases from backup archive"
        )

        true
      rescue StandardError => e
        @error_message = e.message
        Rails.logger.error "Import error: #{e.message}\n#{e.backtrace.join("\n")}"
        ActivityLog.create!(
          action: "import",
          target: "backup",
          level: :error,
          description: "Failed to restore backup: #{e.message}"
        )
        false
      ensure
        # Clean up temporary files
        FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      end
    end
  end
end
