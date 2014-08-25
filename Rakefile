require 'corundum/tasklibs'
#require 'mattock/yard_extensions'

module Corundum
  register_project(__FILE__)

  tk = Toolkit.new do |tk|
    tk.file_lists.project = [__FILE__]
    tk.file_lists.test << FileList["spec2/**/*.rb"]
    tk.file_lists.test << FileList["spec3/**/*.rb"]
  end

  tk.in_namespace do
    GemspecFiles.new(tk)
    %w{debug profanity racism ableism sexism issues}.each do |type|
      QuestionableContent.new(tk) do |qc|
        qc.type = type
      end
    end

    rspec = RSpec.new(tk) do |rspec|
      if ENV["TARGET_RSPEC"]=="3"
        rspec.rspec_opts << "-O rspec3.conf"
        rspec.files_to_run = "spec3"
      else
        rspec.rspec_opts << "-O rspec2.conf"
        rspec.files_to_run = "spec2"
      end
    end
    cov = SimpleCov.new(tk, rspec) do |cov|
      cov.threshold = 75
    end
    gem = GemBuilding.new(tk)
    cutter = GemCutter.new(tk,gem)
    vc = Git.new(tk) do |vc|
      vc.branch = "master"
    end
  end
end

task :default => [:release, :publish_docs]
