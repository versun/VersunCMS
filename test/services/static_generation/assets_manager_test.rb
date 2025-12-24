require "test_helper"
require "tmpdir"

class StaticGeneration::AssetsManagerTest < ActiveSupport::TestCase
  test "ensure_available copies assets into output directory when output differs from public" do
    Dir.mktmpdir("assets_manager_public") do |public_dir|
      Dir.mktmpdir("assets_manager_output") do |output_dir|
        public_dir = Pathname.new(public_dir)
        output_dir = Pathname.new(output_dir)

        source_assets = public_dir.join("assets")
        FileUtils.mkdir_p(source_assets)
        File.write(source_assets.join(".sprockets-manifest-test.json"), { files: {} }.to_json)
        File.write(source_assets.join("app.css"), "body{}")

        manager = StaticGeneration::AssetsManager.new(public_dir: public_dir, event: Rails.event)
        manager.ensure_available!(output_dir: output_dir, precompile: false)

        assert File.exist?(output_dir.join("assets", "app.css"))
        assert File.exist?(output_dir.join("assets", ".sprockets-manifest-test.json"))
      end
    end
  end

  test "ensure_available does not raise when assets missing and precompile is false" do
    Dir.mktmpdir("assets_manager_public") do |public_dir|
      Dir.mktmpdir("assets_manager_output") do |output_dir|
        public_dir = Pathname.new(public_dir)
        output_dir = Pathname.new(output_dir)

        manager = StaticGeneration::AssetsManager.new(public_dir: public_dir, event: Rails.event)

        assert_nothing_raised do
          manager.ensure_available!(output_dir: output_dir, precompile: false)
        end

        refute Dir.exist?(output_dir.join("assets"))
      end
    end
  end

  test "ensure_available runs injected precompile hook when assets missing and precompile is true" do
    Dir.mktmpdir("assets_manager_public") do |public_dir|
      Dir.mktmpdir("assets_manager_output") do |output_dir|
        public_dir = Pathname.new(public_dir)
        output_dir = Pathname.new(output_dir)

        precompile_hook = lambda do
          assets = public_dir.join("assets")
          FileUtils.mkdir_p(assets)
          File.write(assets.join(".manifest.json"), {}.to_json)
          File.write(assets.join("generated.js"), "console.log('ok')")
        end

        manager = StaticGeneration::AssetsManager.new(
          public_dir: public_dir,
          event: Rails.event,
          precompile_assets: precompile_hook
        )
        manager.ensure_available!(output_dir: output_dir, precompile: true)

        assert File.exist?(output_dir.join("assets", "generated.js"))
      end
    end
  end
end
