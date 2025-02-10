# config/initializers/git_version.rb
module VersunCms
  class Application
    def self.git_version
      @git_version ||= `git rev-parse HEAD`.strip[0..7]
    end
  end
end
