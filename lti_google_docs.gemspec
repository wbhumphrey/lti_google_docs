$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "lti_google_docs/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "lti_google_docs"
  s.version     = LtiGoogleDocs::VERSION
  s.authors     = ["University of Missouri"]
  s.email       = ["babiuchr@missouri.edu"]
  s.homepage    = "http://www.missouri.edu"
  s.summary     = "Google Drive Integration into Canvas."
  s.description = "Rails Engine serving as an LTI for Canvas"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.1.1"
  s.add_dependency "ims-lti", "~> 1.1.4"

  s.add_development_dependency "sqlite3"
end
