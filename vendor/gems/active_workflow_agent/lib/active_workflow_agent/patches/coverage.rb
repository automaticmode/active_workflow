require 'simplecov'

if !ENV['COVERAGE']
  require 'coveralls'
  module Coveralls
    module Configuration
      def self.root
	File.expand_path(File.join(Dir.pwd, '../..'))
      end
    end
  end
end

SimpleCov.root File.expand_path(File.join(Dir.pwd, '../..'))
SimpleCov.start :rails do
  add_filter do |src|
    !(src.filename =~ /^#{SimpleCov.root}\/lib\//)
  end
end
