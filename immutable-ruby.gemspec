# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "immutable/version"

Gem::Specification.new do |spec|
  spec.name          = "immutable-ruby"
  spec.version       = Immutable::VERSION
  spec.authors       = ["Alex Dowad", "Dov Murik", "Xavier Shay", "Simon Harris"]
  spec.email         = ["haruki_zaemon@mac.com"]
  spec.summary       = %q{Efficient, immutable, thread-safe collection classes for Ruby}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/immutable-ruby/immutable-ruby"
  spec.license       = "MIT"
  spec.date          = Time.now.strftime("%Y-%m-%d")

  spec.platform      = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 2.0.0"

  spec.files         = Dir["lib/**/*"]
  spec.test_files    = Dir["spec/**/*"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency     "concurrent-ruby", "~> 1.0.0"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 10.1"
  spec.add_development_dependency "yard", "~> 0.8"
  spec.add_development_dependency "pry", "~> 0.9"
  spec.add_development_dependency "pry-doc", "~> 0.6"
  spec.add_development_dependency "benchmark-ips", "~> 2.1"
end
