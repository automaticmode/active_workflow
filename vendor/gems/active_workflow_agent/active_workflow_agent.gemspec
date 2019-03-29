# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'active_workflow_agent/version'

Gem::Specification.new do |spec|
  spec.name          = "active_workflow_agent"
  spec.version       = ActiveWorkflowAgent::VERSION
  spec.authors       = ["Automatic Mode Labs"]
  spec.email         = "info@automaticmode.com"
  spec.summary       = %q{Helpers for making new ActiveWorkflow Agents}
  spec.homepage      = "https://github.com/automaticmode/active_workflow"
  spec.license       = "MIT"

  spec.files         = Dir['LICENSE.txt', 'lib/**/*', 'bin/*']
  spec.executables   = Dir['bin/*'].map { |p| File.basename(p) }
  spec.test_files    = Dir['spec/**/*']
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'thor'
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "simplecov", "~> 0.16.1"
  spec.add_development_dependency "guard", "~> 2.13.0"
  spec.add_development_dependency "guard-rspec", "~> 4.6.5"
end
