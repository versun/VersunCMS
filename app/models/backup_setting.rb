class BackupSetting < ApplicationRecord
  validates :repository_url, presence: true
  validates :branch_name, presence: true

  def self.generate_ssh_key_pair(email = nil)
    require "tempfile"

    # Create temporary directory for key generation
    temp_dir = Dir.mktmpdir
    key_path = File.join(temp_dir, "temp_key")

    begin
      # Generate key using ssh-keygen
      email_comment = email.present? ? "-C '#{email}'" : ""
      system("ssh-keygen -t ed25519 -f #{key_path} -N '' #{email_comment}")

      # Read the generated keys
      private_key = File.read("#{key_path}")
      public_key = File.read("#{key_path}.pub")

      {
        private_key: private_key,
        public_key: public_key
      }
    ensure
      # Clean up temporary files
      FileUtils.remove_entry temp_dir
    end
  end
end
