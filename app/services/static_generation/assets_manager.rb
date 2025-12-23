module StaticGeneration
  class AssetsManager
    def initialize(public_dir:, event: Rails.event, precompile_assets: nil)
      @public_dir = public_dir
      @event = event
      @precompile_assets = precompile_assets || method(:default_precompile_assets!)
    end

    def ensure_available!(output_dir:, precompile: true)
      source_assets_dir = @public_dir.join("assets")
      unless assets_present?(source_assets_dir)
        if precompile
          @precompile_assets.call
        else
          @event.notify(
            "static_generator.assets_missing",
            level: "warn",
            component: "StaticGenerator",
            source: source_assets_dir.to_s
          )
          return
        end
      end

      unless assets_present?(source_assets_dir)
        @event.notify(
          "static_generator.assets_still_missing",
          level: "error",
          component: "StaticGenerator",
          source: source_assets_dir.to_s
        )
        raise "Assets are missing after precompile: #{source_assets_dir}"
      end

      return if output_dir.to_s == @public_dir.to_s

      dest_assets_dir = output_dir.join("assets")
      FileUtils.rm_rf(dest_assets_dir) if Dir.exist?(dest_assets_dir)
      FileUtils.mkdir_p(output_dir)
      FileUtils.cp_r(source_assets_dir, dest_assets_dir)
      @event.notify("static_generator.assets_copied", level: "info", component: "StaticGenerator", destination: dest_assets_dir.to_s)
    end

    private

    def assets_present?(assets_dir)
      return false unless Dir.exist?(assets_dir)

      manifest = Dir.glob(assets_dir.join(".sprockets-manifest*.json")).first ||
        Dir.glob(assets_dir.join(".manifest.json")).first
      return true if manifest.present?

      Dir.glob(assets_dir.join("**/*")).any? { |path| File.file?(path) }
    end

    def default_precompile_assets!
      @event.notify("static_generator.assets_precompile_started", level: "info", component: "StaticGenerator")

      require "rake"
      Rails.application.load_tasks unless Rake::Task.task_defined?("assets:precompile")

      task = Rake::Task["assets:precompile"]
      task.reenable
      task.invoke

      @event.notify("static_generator.assets_precompile_complete", level: "info", component: "StaticGenerator")
    rescue => e
      @event.notify(
        "static_generator.assets_precompile_failed",
        level: "error",
        component: "StaticGenerator",
        error: e.message
      )
      raise
    end
  end
end
