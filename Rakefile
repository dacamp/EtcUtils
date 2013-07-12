require "rake"
require "rake/testtask"

desc "Default: run unit tests."
task :default => :test

desc "Test EtcUtils"
Rake::TestTask.new(:test) do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/**/test_*.rb']
end