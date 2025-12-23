require "test_helper"
require "securerandom"
require "stringio"

class StaticGeneratorTest < ActiveSupport::TestCase
  def setup
    @settings = Setting.first_or_create
    @original_deploy_provider = @settings.deploy_provider
    @original_path = @settings.local_generation_path
  end

  def teardown
    @settings.update!(
      deploy_provider: @original_deploy_provider,
      local_generation_path: @original_path
    )
  end

  test "output_dir normalizes relative local_generation_path to Rails.root" do
    messy_public_path = "#{Rails.root.join('public')}/"
    @settings.update!(deploy_provider: "local", local_generation_path: messy_public_path)
    assert_equal StaticGenerator::PUBLIC_DIR.to_s, StaticGenerator.new.output_dir.to_s
  end

  test "output_dir normalizes dot segments" do
    messy_public_path = "#{Rails.root.join('public')}/./"
    @settings.update!(deploy_provider: "local", local_generation_path: messy_public_path)
    assert_equal StaticGenerator::PUBLIC_DIR.to_s, StaticGenerator.new.output_dir.to_s
  end

  test "export_blob exports non-variable images like SVG" do
    output_dir = Rails.root.join("tmp", "static_generator_test_output_#{Process.pid}_#{SecureRandom.hex(4)}")
    FileUtils.rm_rf(output_dir)

    @settings.update!(
      deploy_provider: "local",
      local_generation_path: output_dir.to_s
    )

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <rect width="10" height="10" fill="red"/>
      </svg>
    SVG

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(svg),
      filename: "test.svg",
      content_type: "image/svg+xml"
    )

    generator = StaticGenerator.new
    static_path = generator.send(:export_blob, blob, force: true)

    assert static_path.present?
    assert_match(%r{\A/uploads/#{blob.id}-test\.svg\z}, static_path)
    assert File.exist?(generator.output_dir.join(static_path.delete_prefix("/")))
  ensure
    FileUtils.rm_rf(output_dir)
  end
end
