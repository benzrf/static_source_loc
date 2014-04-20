require './lib/static_source_loc'

Gem::Specification.new do |s|
  s.name        = 'static_source_loc'
  s.version     = StaticSourceLoc::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'Statically find definitions.'
  s.description = 'Locate module, class, or method defs by name in a project tree.'
  s.authors     = ['benzrf']
  s.email       = 'benzrf@benzrf.com'
  s.files       = `git ls-files lib *.md LICENSE`.split("\n")
  s.homepage    = 'http://rubygems.org/gems/static_source_loc'
  s.license     = 'GPL'

  s.add_runtime_dependency 'ruby_parser'
end

