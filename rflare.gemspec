Gem::Specification.new do |s|
  s.name        = 'rflare'
  s.version     = '0.0.0'
  s.summary     = "Ruby version of Flare"
  s.files       = ['lib/rflare.rb', '.gemtest', 'Rakefile']
  s.test_files  = ['test/test_rflare.rb']
  s.executables = ["rflare"]
  s.homepage    =  'https://research.microsoft.com/pubs/214302/flashrelate-tech-report-April2014.pdf'
  s.authors     = ["Nick White"]

  s.add_runtime_dependency 'tgf', '~> 1'
  s.add_development_dependency 'rake'
end
