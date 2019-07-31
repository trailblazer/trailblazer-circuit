require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["**/*_test.rb"] - FileList["test/docs/*"] + ["test/docs/activity_test.rb"]
end

RuboCop::RakeTask.new

task :default => :test
