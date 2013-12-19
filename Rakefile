require "rake"
require "rake/testtask"
require "bundler/gem_tasks"
require 'rake/extensiontask'

desc "Default: run unit tests."
task :default => :test

desc "Test EtcUtils"
Rake::TestTask.new(:test) do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/**/test_*.rb']
end

Rake::ExtensionTask.new 'etcutils' do |ext|
  ext.lib_dir = "lib/etcutils"
end
