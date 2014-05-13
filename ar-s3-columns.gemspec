# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ar_s3_columns/version'

Gem::Specification.new do |spec|
  spec.name          = "ar-s3-columns"
  spec.version       = S3Columns::VERSION
  spec.authors       = ["Alex Chee"]
  spec.email         = ["alexchee11@gmail.com"]
  spec.summary       = %q{ActiveRecord::Model extension to add an column that on AWS S3.}
  spec.description   = %q{ActiveRecord::Model extension to write/read an column on AWS S3.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "mocha"

  spec.add_dependency 'activesupport', '~> 4.0'
  spec.add_dependency 'activemodel', '~> 4.0'
  spec.add_dependency 'rails', '~> 4.0'
  spec.add_dependency 'aws-sdk', '>= 1.39.0'
  spec.add_dependency 'retryable', '>= 1.3.5'
  spec.add_dependency 'simple_uuid', '>= 0.4.0'
end
