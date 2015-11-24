$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "dc_scheduler/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "dc_scheduler"
  s.version     = DcScheduler::VERSION
  s.authors     = ["Yecheng Xu"]
  s.email       = ["xyc0562@gmail.com"]
  s.homepage    = "https://github.com/xyc0562/dc_scheduler"
  s.summary     = "A scheduler convenience library"
  s.description = "This gem depends on apartment (multi-tenancy), rufus-scheduler (scheduling) and resque (async execution)."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.2"
  s.add_dependency "rufus-scheduler", "~> 3.1.8"
  s.add_dependency "resque", "~> 1.25.2"
  s.add_dependency "parse-cron", "~> 0.1.4"
  s.add_dependency "rollbar", "~> 1.5.1"
  s.add_dependency "apartment", "~> 1.0.2"

  s.add_development_dependency "sqlite3"
end
