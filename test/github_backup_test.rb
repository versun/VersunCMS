#!/usr/bin/env ruby
# Test script for GitHub Backup functionality
# Run with: rails runner test/github_backup_test.rb

puts "=" * 80
puts "GitHub Backup Feature Test"
puts "=" * 80
puts

# 1. Check if Setting exists
setting = Setting.first
if setting.nil?
  puts "❌ No Setting record found. Please create one first."
  exit 1
end

puts "✅ Setting record found"

# 2. Check GitHub backup configuration
puts "\nGitHub Backup Configuration:"
puts "  Enabled: #{setting.github_backup_enabled}"
puts "  Repository URL: #{setting.github_repo_url || '(not set)'}"
puts "  Token: #{setting.github_token.present? ? '***configured***' : '(not set)'}"
puts "  Branch: #{setting.github_backup_branch || 'main'}"
puts "  Git User: #{setting.git_user_name || 'VersunCMS'}"
puts "  Git Email: #{setting.git_user_email || 'backup@versuncms.local'}"
puts "  Schedule: #{setting.github_backup_cron || '(not set)'}"
puts "  Last Backup: #{setting.last_backup_at || 'Never'}"

# 3. Check if fully configured
if setting.github_backup_configured?
  puts "\n✅ GitHub backup is fully configured"
else
  puts "\n⚠️  GitHub backup is not fully configured"
  puts "   Please set: repository URL, token, and enable the feature"
  exit 0
end

# 4. Check content availability
article_count = Article.published.count
page_count = Page.published.count

puts "\nContent to backup:"
puts "  Articles (published): #{article_count}"
puts "  Pages (published): #{page_count}"

if article_count == 0 && page_count == 0
  puts "\n⚠️  No published content to backup"
  exit 0
end

# 5. Test GithubBackupService (dry run check)
puts "\nTesting GithubBackupService initialization..."
begin
  service = GithubBackupService.new
  puts "✅ GithubBackupService initialized successfully"
rescue => e
  puts "❌ Failed to initialize service: #{e.message}"
  exit 1
end

# 6. Optional: Run actual backup (commented out by default)
puts "\n" + "=" * 80
puts "Test completed! ✅"
puts "=" * 80
puts
puts "To run an actual backup, execute:"
puts "  GithubBackupJob.perform_later"
puts
puts "Or trigger it from the admin interface at:"
puts "  /admin/migrates"
puts
