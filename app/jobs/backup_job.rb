class BackupJob < ApplicationJob
  queue_as :default

  def perform
    settings = BackupSetting.first
    return unless settings

    log = BackupLog.create!(status: :started, message: 'Starting backup...')

    begin
      setup_ssh(settings)
      perform_git_backup(settings)
      log.update!(status: :completed, message: 'Backup completed successfully')
    rescue => e
      log.update!(status: :failed, message: "Backup failed: #{e.message}")
      raise e
    ensure
      cleanup_ssh
    end
  end

  private

  def setup_ssh(settings)
    ssh_dir = File.join(Dir.home, '.ssh')
    FileUtils.mkdir_p(ssh_dir, mode: 0700) unless Dir.exist?(ssh_dir)
    
    private_key_path = File.join(ssh_dir, 'backup_id_rsa')
    Rails.logger.info "Writing private key to: #{private_key_path}"
    
    # Debug: Check key format
    Rails.logger.info "Private key format check:"
    Rails.logger.info "Private key starts with: #{settings.ssh_private_key.lines.first}"
    Rails.logger.info "Public key starts with: #{settings.ssh_public_key.lines.first}"
    
    # Write private key with correct permissions
    File.write(private_key_path, settings.ssh_private_key)
    FileUtils.chmod(0600, private_key_path)
    
    # Write public key for reference
    public_key_path = File.join(ssh_dir, 'backup_id_rsa.pub')
    File.write(public_key_path, settings.ssh_public_key)
    FileUtils.chmod(0644, public_key_path)
    
    # Test SSH connection
    Rails.logger.info "Testing SSH connection..."
    test_cmd = "ssh -v -i #{private_key_path} -o StrictHostKeyChecking=no -T git@github.com"
    Rails.logger.info "Running command: #{test_cmd}"
    test_output = `#{test_cmd} 2>&1`
    Rails.logger.info "SSH test output: #{test_output}"
    
    # Check key permissions and content
    Rails.logger.info "Private key permissions: #{File.stat(private_key_path).mode.to_s(8)}"
    Rails.logger.info "SSH directory permissions: #{File.stat(ssh_dir).mode.to_s(8)}"
    Rails.logger.info "Private key content preview:"
    Rails.logger.info `head -n 2 #{private_key_path}`
    Rails.logger.info "Public key content:"
    Rails.logger.info `cat #{public_key_path}`
  end

  def perform_git_backup(settings)
    backup_path = Rails.root.join('storage', 'backup').to_s
    FileUtils.mkdir_p(backup_path) unless Dir.exist?(backup_path)
    
    # Initialize git repo if not exists
    unless Dir.exist?(File.join(backup_path, '.git'))
      Rails.logger.info "Initializing new git repository in #{backup_path}"
      system('git init', chdir: backup_path) or raise 'Failed to initialize git repository'
      
      # Create .gitignore to track JSON files and attachments
      File.write(File.join(backup_path, '.gitignore'), <<~GITIGNORE)
        # Ignore everything
        *
        # Except JSON files and attachments directory
        !*.json
        !attachments/
        !attachments/**/*
        !.gitignore
      GITIGNORE
    end
    
    # Create attachments directory
    attachments_dir = File.join(backup_path, 'attachments')
    FileUtils.mkdir_p(attachments_dir)
    
    # Export database content
    Rails.logger.info "Exporting database content"
    
    # Export articles with rich text content and attachments
    articles_data = Article.all.map do |article|
      article_data = article.as_json
      
      # Add rich text content
      if article.content.present?
        article_data['content'] = {
          html: article.content.body.to_html,
          attachments: backup_attachments(article.content, attachments_dir)
        }
      end
      
      article_data
    end
    
    # Export settings with rich text content
    settings_data = Setting.all.map do |setting|
      setting_data = setting.as_json
      
      # Add rich text footer
      if setting.footer.present?
        setting_data['footer'] = {
          html: setting.footer.body.to_html,
          attachments: backup_attachments(setting.footer, attachments_dir)
        }
      end
      
      setting_data
    end
    
    # Prepare backup data
    data = {
      articles: articles_data,
      settings: settings_data,
      backup_time: Time.current
    }
    
    # Write to JSON file with timestamp
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = File.join(backup_path, "blog_backup_#{timestamp}.json")
    File.write(backup_file, JSON.pretty_generate(data))
    Rails.logger.info "Database content exported to #{backup_file}"
    
    # Debug information
    Rails.logger.info "Current directory: #{backup_path}"
    Rails.logger.info "Git status: #{`git -C #{backup_path} status`}"
    Rails.logger.info "Remote repositories: #{`git -C #{backup_path} remote -v`}"
    
    # Configure git
    system("git config user.name '#{settings.git_name}'", chdir: backup_path) or raise 'Failed to set git name'
    system("git config user.email '#{settings.git_email}'", chdir: backup_path) or raise 'Failed to set git email'
    
    # Check and configure remote repository
    remote_url = settings.repository_url
    Rails.logger.info "Expected remote URL: #{remote_url}"
    
    # Get current remote URL directly from git config in backup directory
    current_remote = `git -C #{backup_path} config --get remote.origin.url`.strip
    Rails.logger.info "Current remote URL: #{current_remote}"
    
    if current_remote != remote_url
      Rails.logger.info "Updating remote repository URL"
      # Force remove and add the remote
      system("git -C #{backup_path} remote remove origin") # Don't raise error if remote doesn't exist
      system("git -C #{backup_path} remote add origin #{remote_url}") or raise 'Failed to add remote repository'
      
      # Verify the remote was updated
      new_remote = `git -C #{backup_path} config --get remote.origin.url`.strip
      if new_remote != remote_url
        raise "Failed to update remote URL. Expected: #{remote_url}, Got: #{new_remote}"
      end
      Rails.logger.info "Remote URL updated successfully"
    end
    
    # Check if branch exists locally
    branch_exists = system("git -C #{backup_path} show-ref --verify --quiet refs/heads/#{settings.branch_name}")
    Rails.logger.info "Branch '#{settings.branch_name}' exists: #{branch_exists}"
    
    unless branch_exists
      Rails.logger.info "Creating new branch: #{settings.branch_name}"
      system("git -C #{backup_path} checkout -b #{settings.branch_name}") or raise "Failed to create branch #{settings.branch_name}"
    else
      Rails.logger.info "Switching to branch: #{settings.branch_name}"
      system("git -C #{backup_path} checkout #{settings.branch_name}") or raise "Failed to switch to branch #{settings.branch_name}"
    end
    
    # Add all JSON files and attachments if they exist
    Rails.logger.info "Staging JSON files..."
    system("git -C #{backup_path} add *.json") or raise 'Failed to stage changes'
    
    # Add attachments only if the directory exists and is not empty
    attachments_dir = File.join(backup_path, 'attachments')
    if Dir.exist?(attachments_dir) && !Dir.empty?(attachments_dir)
      Rails.logger.info "Staging attachments directory..."
      # Force add all files in attachments directory
      system("git -C #{backup_path} add -f attachments/") or raise 'Failed to stage attachments'
      # Verify attachments were staged
      staged_files = `git -C #{backup_path} status --porcelain attachments/`
      Rails.logger.info "Staged attachment files: \n#{staged_files}"
      if staged_files.empty?
        Rails.logger.info "No attachment files were staged, directory might be empty"
      end
    else
      Rails.logger.info "No attachments to backup"
      # Remove attachments directory from git if it exists
      if Dir.exist?(attachments_dir)
        Rails.logger.info "Removing empty attachments directory from git..."
        system("git -C #{backup_path} rm -r --cached attachments/") # ignore errors
        FileUtils.rm_rf(attachments_dir)
      end
    end
    
    # Check if there are any changes
    changes = `git -C #{backup_path} status --porcelain`
    Rails.logger.info "Git status porcelain output: #{changes}"
    
    if changes.strip.empty?
      Rails.logger.info "No changes detected in git status"
      return
    end
    
    Rails.logger.info "Changes detected: \n#{changes}"
    
    # Commit changes
    commit_message = "Backup: #{timestamp} - #{Article.count} articles"
    commit_output = `git -C #{backup_path} commit -m "#{commit_message}" 2>&1`
    Rails.logger.info "Commit output: #{commit_output}"
    
    # Set GIT_SSH_COMMAND to use our specific key
    ENV['GIT_SSH_COMMAND'] = "ssh -i #{File.join(Dir.home, '.ssh', 'backup_id_rsa')} -o StrictHostKeyChecking=no"
    
    # Push changes
    Rails.logger.info "Pushing to remote repository..."
    push_output = `git -C #{backup_path} push -u origin #{settings.branch_name} 2>&1`
    Rails.logger.info "Push output: #{push_output}"
    unless $?.success?
      raise "Failed to push changes: #{push_output}"
    end
    Rails.logger.info "Push completed successfully"
  ensure
    ENV['GIT_SSH_COMMAND'] = nil
  end

  def backup_attachments(rich_text, attachments_dir)
    return [] unless rich_text&.body&.present?
    
    Rails.logger.info "Processing attachments for rich text content"
    attachments = []
    
    # Process all attachables from rich text
    rich_text.body.attachables.each do |attachable|
      Rails.logger.info "Processing attachable: #{attachable.class}"
      
      if attachable.is_a?(ActiveStorage::Blob)
        if attachment_data = backup_blob(attachable, attachments_dir)
          attachments << attachment_data
        end
      end
    end
    
    attachments
  end
  
  def backup_blob(blob, attachments_dir)
    Rails.logger.info "Backing up blob: #{blob.filename}"
    
    begin
      filename = blob.filename.to_s
      # Use blob key as directory to avoid filename conflicts
      attachment_path = File.join(attachments_dir, blob.key, filename)
      Rails.logger.info "Saving attachment to: #{attachment_path}"
      
      # Create subdirectory
      FileUtils.mkdir_p(File.dirname(attachment_path))
      
      # Download and save the file
      File.open(attachment_path, 'wb') do |file|
        blob.download { |chunk| file.write(chunk) }
      end
      
      # Return attachment metadata
      {
        key: blob.key,
        filename: filename,
        content_type: blob.content_type,
        byte_size: blob.byte_size,
        checksum: blob.checksum,
        created_at: blob.created_at
      }
    rescue => e
      Rails.logger.error "Failed to backup blob #{blob.filename}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end

  def cleanup_ssh
    private_key_path = File.join(Dir.home, '.ssh', 'backup_id_rsa')
    File.delete(private_key_path) if File.exist?(private_key_path)
  end
end
