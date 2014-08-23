require 'corundum/tasklibs'
require 'mattock/yard_extensions'

module Corundum
  register_project(__FILE__)

  tk = Toolkit.new do |tk|
    tk.file_lists.project = [__FILE__]
  end

  tk.in_namespace do
    GemspecFiles.new(tk)
    %w{debug profanity racism ableism sexism issues}.each do |type|
      QuestionableContent.new(tk) do |qc|
        qc.type = type
      end
    end

    rspec = RSpec.new(tk) do |rspec|
      if ENV["TARGET_RSPEC"]="3"
        rspec.rspec_opts << "-O rspec3.conf"
        rspec.files_to_run = "spec3"
      else
        rspec.rspec_opts << "-O rspec2.conf"
        rspec.files_to_run = "spec2"
      end
    end
    cov = SimpleCov.new(tk, rspec) do |cov|
      cov.threshold = 80
    end
    gem = GemBuilding.new(tk)
    cutter = GemCutter.new(tk,gem)
    email = Email.new(tk)
    vc = Git.new(tk) do |vc|
      vc.branch = "master"
    end
    task tk.finished_files.build => vc["is_checked_in"]
    yd = YARDoc.new(tk) do |yd|
    end
    all_docs = DocumentationAssembly.new(tk, yd, rspec, cov)
    pages = GithubPages.new(all_docs)
  end
end

task :default => [:release, :publish_docs]
