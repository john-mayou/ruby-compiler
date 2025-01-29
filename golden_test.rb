require 'minitest/autorun'

require_relative 'golden.rb'

module Golden
  class TestFileShaStore < Minitest::Test
    def setup
      @rb_sha_file = Tempfile.new
      @js_sha_file = Tempfile.new
    end

    def teardown
      @rb_sha_file.close
      @js_sha_file.close
      @rb_sha_file.unlink
      @js_sha_file.unlink
    end

    def build_store
      FileShaStore.new(
        rb_sha_path: @rb_sha_file.path,
        js_sha_path: @js_sha_file.path,
        logger: Logger.new(nil)
      )
    end

    def test_update_rb
      store = build_store
      refute store.match?('file.rb', 'rb')
      store.update('file.rb', 'rb')
      assert store.match?('file.rb', 'rb')
      store.update('file.rb', 'new rb')
      refute store.match?('file.rb', 'rb')
    end

    def test_update_js
      store = build_store
      refute store.match?('file.js', 'js')
      store.update('file.js', 'js')
      assert store.match?('file.js', 'js')
      store.update('file.js', 'new js')
      refute store.match?('file.js', 'js')
    end

    def test_existing_file_rb
      store = build_store
      store.update('file.rb', 'rb')
      store = build_store
      assert store.match?('file.rb', 'rb')
    end

    def test_existing_file_js
      store = build_store
      store.update('file.js', 'js')
      store = build_store
      assert store.match?('file.js', 'js')
    end
  end
end