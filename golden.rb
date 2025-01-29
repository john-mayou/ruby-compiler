require 'fileutils'
require 'logger'
require 'digest'

module Golden
  class FileLocator
    def golden_files
      files = Dir.glob(File.expand_path('testdata/rb/*.rb')).map { File.basename(it, '.rb') }
      if files.count < 10
        raise RuntimeError, "Expected to find a few more files, only found #{files.count}"
      end
      files
    end
  end

  class FileShaStore

    RB_SHA_PATH = File.expand_path('testdata/rb_sha.txt').freeze
    JS_SHA_PATH = File.expand_path('testdata/js_sha.txt').freeze

    def initialize(
      rb_sha_path: RB_SHA_PATH,
      js_sha_path: JS_SHA_PATH,
      logger: Logger.new($stdout)
    )
      @rb_sha_path = rb_sha_path
      @js_sha_path = js_sha_path
      @logger = logger
      
      @rb_map = load_map(@rb_sha_path)
      @js_map = load_map(@js_sha_path)
    end

    def match?(golden, code)
      sha_new = Digest::SHA1.hexdigest(code)
      sha_old = (
        if golden.end_with?('.rb')
          @rb_map[golden]
        elsif golden.end_with?('.js')
          @js_map[golden]
        else
          raise ArgumentError, "Expected golden file ext: #{golden}"
        end
      )

      match = sha_old == sha_new

      if !match
        @logger.info "#{File.basename(golden)} #{File.extname(golden).gsub('.', '')} golden code different: '#{sha_old}' != '#{sha_new}'"
      end

      match
    end

    def update(golden, code)
      if golden.end_with?('.rb')
        @rb_map[golden] = Digest::SHA1.hexdigest(code)
        @logger.info "#{golden} rb golden sha updated: #{@rb_map[golden]}"
        write_map(@rb_sha_path, @rb_map)
      elsif golden.end_with?('.js')
        @js_map[golden] = Digest::SHA1.hexdigest(code)
        @logger.info "#{golden} js golden sha updated: #{@js_map[golden]}"
        write_map(@js_sha_path, @js_map)
      else
        raise ArgumentError, "Expected golden file ext: #{golden}"
      end
    end

    private

    def load_map(path)
      if !File.exist?(path)
        FileUtils.touch(path)
        return {}
      end

      File.readlines(path).each_with_object({}) do |line, map|
        sha, golden = line.split(' ')
        map[golden] = sha
      end
    end

    def write_map(path, map)
      File.open(path, 'w') do |file|
        map.each do |golden, sha|
          file.puts("#{sha} #{golden}")
        end
      end
    end
  end

  class SyntaxValidator
    class << self
      def ensure_valid_rb(rb)
        Tempfile.open(['file', '.rb']) do |file|
          file.write(rb)
          file.flush

          out, err, status = Open3.capture3("ruby -c \"#{file.path}\"")
          if status.success?
            puts "Ruby: #{out}"
          else
            raise SystemCallError, "Ruby format error: #{err}"
          end
        end
      end

      def ensure_valid_js(js)
        Tempfile.open(['file', '.js']) do |file|
          file.write(js)
          file.flush
          
          out, err, status = Open3.capture3("node --check \"#{file.path}\"")
          if status.success?
            puts "JavaScript: #{out}"
          else
            raise SystemCallError, "JavaScript format error: #{err}"
          end
        end
      end
    end
  end
end