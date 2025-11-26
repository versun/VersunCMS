require "test_helper"

class Admin::MigratesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin) # Assuming there is an admin fixture
    sign_in_as @admin_user
  end

  test "should get index" do
    get admin_migrates_url
    assert_response :success
  end

  test "should import from zip" do
    # Create a dummy zip file
    zip_file = Rails.root.join("tmp", "test_import.zip")
    Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
      zipfile.get_output_stream("test.txt") { |f| f.write "This is a test" }
    end

    file = fixture_file_upload(zip_file, "application/zip")

    assert_enqueued_with(job: ImportFromZipJob) do
      post admin_migrates_url, params: { operation_type: 'import', zip_file: file }
    end

    assert_redirected_to admin_migrates_url
    assert_equal "ZIP Import in progress, please check the logs for details", flash[:notice]

    # Clean up
    FileUtils.rm_f(zip_file)
  end
end
