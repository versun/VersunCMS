require "test_helper"
require "minitest/mock"
require "tempfile"

class SingleFileArchiveServiceTest < ActiveSupport::TestCase
  test "validate_single_file_cli! does not invoke a shell" do
    status = Struct.new(:success?).new(true)
    captured_args = nil

    Open3.stub(:capture3, ->(*args, **_kwargs) { captured_args = args; [ "", "", status ] }) do
      SingleFileArchiveService.new.validate_single_file_cli!
    end

    assert_equal 2, captured_args.length
    assert_equal SingleFileArchiveService::SINGLE_FILE_CLI, captured_args[0]
    assert_equal "--version", captured_args[1]
  end

  test "validate_single_file_cli! auto-installs when missing" do
    status = Struct.new(:success?).new(true)
    capture3_calls = 0

    Open3.stub(:capture3, lambda { |_cmd, *_args, **_kwargs|
      capture3_calls += 1
      raise Errno::ENOENT if capture3_calls == 1
      [ "", "", status ]
    }) do
      service = SingleFileArchiveService.new
      install_called = false

      service.stub(:install_single_file_cli!, -> { install_called = true }) do
        service.validate_single_file_cli!
      end

      assert install_called
    end
  end

  test "validate_single_file_cli! does not auto-install when disabled" do
    previous = ENV["SINGLE_FILE_AUTO_INSTALL"]
    ENV["SINGLE_FILE_AUTO_INSTALL"] = "0"

    Open3.stub(:capture3, ->(*_args, **_kwargs) { raise Errno::ENOENT }) do
      service = SingleFileArchiveService.new

      service.stub(:install_single_file_cli!, -> { flunk "install should not be called when disabled" }) do
        assert_raises(SingleFileArchiveService::SingleFileNotFoundError) do
          service.validate_single_file_cli!
        end
      end
    end
  ensure
    ENV["SINGLE_FILE_AUTO_INSTALL"] = previous
  end

  test "validate_single_file_cli! sanitizes binary output in errors" do
    previous = ENV["SINGLE_FILE_AUTO_INSTALL"]
    ENV["SINGLE_FILE_AUTO_INSTALL"] = "0"

    status = Struct.new(:success?).new(false)

    Open3.stub(:capture3, ->(*_args, **_kwargs) { [ "\xCF".b, "".b, status ] }) do
      error = assert_raises(SingleFileArchiveService::SingleFileNotFoundError) do
        SingleFileArchiveService.new.validate_single_file_cli!
      end

      assert_equal Encoding::UTF_8, error.message.encoding
      assert error.message.valid_encoding?
    end
  ensure
    ENV["SINGLE_FILE_AUTO_INSTALL"] = previous
  end

  test "download_to_io! writes binary data without encoding errors" do
    service = SingleFileArchiveService.new

    service.stub(:http_get_stream!, lambda { |_uri, headers:, limit: 5, &block|
      block.call("\xCF".b)
      block.call("ABC".b)
    }) do
      Tempfile.create("single-file-cli-test") do |tmp|
        tmp.set_encoding(Encoding::UTF_8)

        service.send(:download_to_io!, "https://example.com/single-file", tmp)

        tmp.flush
        tmp.rewind
        assert_equal "\xCFABC".b, tmp.read.b
      end
    end
  end

  test "archive_with_single_file retries with browser-wait-until=load when output missing" do
    service = SingleFileArchiveService.new
    status = Struct.new(:success?).new(true)

    Dir.mktmpdir("rables_archive_test") do |tmpdir|
      output_path = File.join(tmpdir, "out.html")
      calls = []

      service.stub(:generate_filename, "out.html") do
        service.stub(:capture3_with_timeout, lambda { |*args, **_kwargs|
          calls << args

          if args.any? { |arg| arg == "--browser-wait-until=load" }
            File.write(output_path, "<html>ok</html>")
          end

          [ "", "Execution context not found for SingleFile world".b, status ]
        }) do
          assert_equal output_path, service.send(:archive_with_single_file, "https://example.com", tmpdir)
        end
      end

      assert_equal 2, calls.length
      assert calls[0].none? { |arg| arg == "--browser-wait-until=load" }
      assert calls[1].any? { |arg| arg == "--browser-wait-until=load" }
    end
  end

  test "archive_with_single_file raises BrowserNotFoundError when chromium is missing" do
    service = SingleFileArchiveService.new
    status = Struct.new(:success?).new(false)
    previous_auto_install = ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"]
    previous_browser_path = ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"]
    ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"] = "0"
    ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"] = nil

    Dir.mktmpdir("rables_archive_test") do |tmpdir|
      calls = []

      service.stub(:generate_filename, "out.html") do
        service.stub(:find_system_browser_executable, nil) do
          service.stub(:capture3_with_timeout, lambda { |*args, **_kwargs|
            calls << args
            [ "", "Chromium executable not found.".b, status ]
          }) do
            error = assert_raises(SingleFileArchiveService::BrowserNotFoundError) do
              service.send(:archive_with_single_file, "https://example.com", tmpdir)
            end

            assert_match(/chrom/i, error.message)
          end
        end
      end

      assert_equal 1, calls.length
    end
  ensure
    ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"] = previous_auto_install
    ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"] = previous_browser_path
  end

  test "archive_with_single_file auto-installs chromium and passes browser-executable-path" do
    service = SingleFileArchiveService.new
    status = Struct.new(:success?).new(true)
    previous_auto_install = ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"]
    previous_browser_path = ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"]
    ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"] = "1"
    ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"] = nil

    Dir.mktmpdir("rables_archive_test") do |tmpdir|
      output_path = File.join(tmpdir, "out.html")
      calls = []
      install_called = false

      installed_path = File.join(tmpdir, "fake-chrome")

      installed_calls = 0
      service.stub(:find_system_browser_executable, nil) do
        service.stub(:installed_chromium_executable_path, lambda {
          installed_calls += 1
          installed_calls >= 2 ? installed_path : nil
        }) do
          service.stub(:install_chromium!, -> { install_called = true }) do
            service.stub(:generate_filename, "out.html") do
              service.stub(:capture3_with_timeout, lambda { |*args, **kwargs|
                calls << args
                File.write(output_path, "<html>ok</html>")
                [ "", "", status ]
              }) do
                assert_equal output_path, service.send(:archive_with_single_file, "https://example.com", tmpdir)
              end
            end
          end
        end
      end

      assert install_called
      assert_equal 1, calls.length
      assert_includes calls[0], "--browser-executable-path"
      assert_includes calls[0], installed_path
    end
  ensure
    ENV["SINGLE_FILE_BROWSER_AUTO_INSTALL"] = previous_auto_install
    ENV["SINGLE_FILE_BROWSER_EXECUTABLE_PATH"] = previous_browser_path
  end

  test "run_single_file_cli applies 2 minute timeout" do
    service = SingleFileArchiveService.new
    status = Struct.new(:success?).new(true)
    captured_timeout = nil

    service.stub(:capture3_with_timeout, lambda { |*args, chdir:, timeout_seconds:|
      captured_timeout = timeout_seconds
      [ "", "", status ]
    }) do
      Dir.mktmpdir("rables_archive_test") do |tmpdir|
        service.send(:run_single_file_cli, "https://example.com", "out.html", tmpdir)
      end
    end

    assert_equal 120, captured_timeout
  end
end
