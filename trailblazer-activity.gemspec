lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'trailblazer/activity/version'

Gem::Specification.new do |spec|
  spec.name          = "trailblazer-activity"
  spec.version       = Trailblazer::Version::Activity::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]

  spec.summary       = %q{Runtime code for Trailblazer activities.}
  spec.homepage      = "http://trailblazer.to"
  spec.licenses      = ["LGPL-3.0"]

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test)/})
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "trailblazer-context", ">= 0.1.4"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "trailblazer-developer"

  spec.required_ruby_version = '>= 2.1.0'
end
