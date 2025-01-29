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

  class SyntaxValidator
    class << self
      def ensure_valid_rb(path)
        _out, err, status = Open3.capture3("ruby -c \"#{path}\"")
        if !status.success?
          raise SystemCallError, "Ruby format error: #{err}"
        end
      end

      def ensure_valid_js(path)
        _out, err, status = Open3.capture3("node --check \"#{path}\"")
        if !status.success?
          raise SystemCallError, "JavaScript format error: #{err}"
        end
      end
    end
  end
end