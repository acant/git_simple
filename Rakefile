require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'cucumber'
require 'cucumber/rake/task'
require 'pathname'

RSpec::Core::RakeTask.new do |task|
  task.rspec_opts = '--warnings'
end

RuboCop::RakeTask.new do |task|
  Pathname(Rake.application.original_dir).join('tmp').mkpath
  task.options = %w[
    --display-cop-names
    --extra-details
    --display-style-guide
    --fail-level error
    --format progress
    --format simple --out tmp/rubocop.txt
  ]
end

Cucumber::Rake::Task.new(:features)

task default: %i[spec features rubocop]
