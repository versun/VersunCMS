class BackupJob < ApplicationJob
  queue_as :default
  require 'git'
  require_relative '../models/tools/export'

  def perform
    settings = BackupSetting.first
    return unless settings
  
    log = BackupLog.create!(status: :started, message: "Starting backup...")
  
    begin
      setup_ssh(settings) do
        # Create zip backup first
        export = Tools::Export.new
        if export.generate
          timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
          zip_dir = Rails.root.join('storage', 'backup', 'zip')
          FileUtils.mkdir_p(zip_dir)
          backup_zip = File.join(zip_dir, "backup_#{timestamp}.zip")
          FileUtils.mv(export.zip_path, backup_zip)
          
          # Now perform git backup which will include the zip file
          perform_git_backup(settings)
          
          log.update!(status: :completed, message: "Backup completed successfully with zip file: #{backup_zip}")
        else
          log.update!(status: :failed, message: "Zip export failed: #{export.error_message}")
          raise "Zip export failed: #{export.error_message}"
        end
      end
    rescue => e
      log.update!(status: :failed, message: "Backup failed: #{e.message}")
      raise e
    end
  end

  private

  def setup_ssh(settings)
    require 'tempfile'
    
    # Create a temporary file for the private key
    private_key_file = Tempfile.new('git_private_key')
    begin
      private_key_file.write(settings.ssh_private_key)
      private_key_file.close
      
      # Set proper permissions
      FileUtils.chmod(0600, private_key_file.path)
      
      # Configure Git to use this key
      ENV['GIT_SSH_COMMAND'] = "ssh -i #{private_key_file.path} -o StrictHostKeyChecking=no"
      
      yield if block_given?
    ensure
      # Clean up the temporary file
      private_key_file.unlink
    end
  end

  def perform_git_backup(settings)
    raise "Invalid repository URL" unless settings.repository_url =~ %r{\A[a-zA-Z0-9@:/_.-]+\z}
    raise "Invalid branch name" unless settings.branch_name =~ /\A[a-zA-Z0-9_.-]+\z/

    backup_path = Rails.root.join("storage", "backup").to_s
    FileUtils.mkdir_p(backup_path)

    git = if Dir.exist?(File.join(backup_path, ".git"))
      Git.open(backup_path)
    else
      Git.init(backup_path)
      git = Git.open(backup_path)
      git.add_remote('origin', settings.repository_url)
      git
    end

    # Create .gitignore
    update_gitignore(backup_path)

    # Create attachments directory
    attachments_dir = File.join(backup_path, "attachments")
    FileUtils.mkdir_p(attachments_dir)

    # Export database content
    export_database_content(backup_path, attachments_dir)

    # Git operations
    git.config('user.name', 'Backup Job')
    git.config('user.email', 'backup@job')

    # Add all changes
    git.add(all: true)

    # Only commit if there are changes
    if git.status.changed.any? || git.status.added.any? || git.status.deleted.any?
      git.commit("Backup #{Time.current}")
      
      # Fetch to ensure we have the latest state
      git.fetch
      
      # Push to the specified branch
      git.push('origin', settings.branch_name, force: true)
    end
  end

  def update_gitignore(backup_path)
    File.write(File.join(backup_path, ".gitignore"), <<~GITIGNORE)
      # Ignore everything
      *
      # Except JSON files and attachments directory
      !*.json
      !attachments/
      !attachments/**/*
      !.gitignore
      # Include zip backups
      !zip/
      !zip/**/*.zip
    GITIGNORE
  end

  def export_database_content(backup_path, attachments_dir)
    # Export articles
    articles_data = Article.all.map do |article|
      article_data = article.as_json
      
      if article.content.present?
        article_data["content"] = {
          html: article.content.body.to_html,
          attachments: backup_attachments(article.content, attachments_dir)
        }
      end
      
      article_data
    end

    File.write(
      File.join(backup_path, "articles.json"),
      JSON.pretty_generate(articles_data)
    )

    # Export settings
    settings_data = Setting.all.map do |setting|
      setting_data = setting.as_json

      if setting.footer.present?
        setting_data["footer"] = {
          html: setting.footer.body.to_html,
          attachments: backup_attachments(setting.footer, attachments_dir)
        }
      end

      setting_data
    end

    File.write(
      File.join(backup_path, "settings.json"),
      JSON.pretty_generate(settings_data)
    )
  end

  def backup_attachments(content, attachments_dir)
    return [] unless content.body.attachments.any?

    content.body.attachments.map do |attachment|
      next unless attachment.file.attached?

      filename = attachment.file.filename.to_s
      path = File.join(attachments_dir, filename)
      
      File.binwrite(path, attachment.file.download)
      filename
    end.compact
  end

  def create_zip_backup
    zip_dir = Rails.root.join("storage", "zip")
    FileUtils.mkdir_p(zip_dir)

    export = Tools::Export.new
    if export.generate
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      zip_filename = "backup_#{timestamp}.zip"
      zip_path = File.join(zip_dir, zip_filename)
      
      FileUtils.mv(export.zip_path, zip_path)
      Rails.logger.info "Created ZIP backup: #{zip_path}"
    else
      Rails.logger.error "Failed to create ZIP backup: #{export.error_message}"
      raise "ZIP backup creation failed: #{export.error_message}"
    end
  end

  def cleanup_ssh
    # Remove the SSH keys after backup
    ssh_dir = File.join(Dir.home, ".ssh")
    FileUtils.rm_f(File.join(ssh_dir, "backup_id_rsa"))
    FileUtils.rm_f(File.join(ssh_dir, "backup_id_rsa.pub"))
    ENV.delete('GIT_SSH_COMMAND')
  end
end
