# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "immutable/version"

Gem::Specification.new do |spec|
  spec.name          = "immutable-ruby"
  spec.version       = Immutable::VERSION
  spec.authors       = ["Alex Dowad", "Dov Murik", "Xavier Shay", "Simon Harris"]
  spec.email         = ["alexinbeijing@gmail.com"]
  spec.summary       = %q{Efficient, immutable, thread-safe collection classes for Ruby}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/immutable-ruby/immutable-ruby"
  spec.license       = "MIT"
  spec.date          = Time.now.strftime("%Y-%m-%d")

  spec.platform      = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 2.4.0"

  spec.files         = Dir["lib/**/*"]
  spec.test_files    = Dir["spec/**/*"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency     "concurrent-ruby", "~> 1.0.0"
  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rspec", "~> 3.7"
  spec.add_development_dependency "rake", "~> 12.2"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "pry", "~> 0.11"
  spec.add_development_dependency "pry-doc", "~> 0.11"
  spec.add_development_dependency "benchmark-ips", "~> 2.7"
end
