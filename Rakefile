require 'corundum/tasklibs'

module Corundum
  register_project(__FILE__)

  tk = Toolkit.new do |tk|
    tk.file_lists.project = [__FILE__]
    tk.file_lists.test << FileList["spec/**/*.rb"]
  end

  tk.in_namespace do
    GemspecFiles.new(tk)
    %w{debug profanity racism ableism sexism issues}.each do |type|
      QuestionableContent.new(tk) do |qc|
        qc.type = type
      end
    end

    rspec = RSpec.new(tk) do |rspec|
      rspec.files_to_run = "spec"
    end
    SimpleCov.new(tk, rspec) do |cov|
      cov.threshold = 93
    end
    gem = GemBuilding.new(tk)
    GemCutter.new(tk,gem)
    Git.new(tk) do |vc|
      vc.branch = "master"
    end
  end
end

Dir['gemfiles/*'].delete_if{|path| path =~ /lock\z/ }.each do |gemfile|
  gemfile_lock = gemfile + ".lock"
  file gemfile_lock => [gemfile, "rspec-steps.gemspec"] do
    Bundler.with_clean_env do
      sh "bundle install --gemfile #{gemfile}"
    end
  end

  desc "Update all the bundler lockfiles for Travis"
  task :travis_gemfiles => gemfile_lock
end

task :default => [:release, :publish_docs]
