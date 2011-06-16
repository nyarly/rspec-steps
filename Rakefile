require 'rubygems'
require 'rubygems/installer'
require 'rake/gempackagetask'
require 'rake/rubygems'
require 'hanna/rdoctask'
require 'rspec/core/rake_task'
require 'mailfactory'
require 'net/smtp'

begin
  speclist = Dir[File.expand_path(__FILE__ +'/../*.gemspec')]
  if speclist.length == 0
    puts "Found no *.gemspec files"
    exit 1
  else if speclist.length > 1
    puts "Found too many *.gemspec files: #{speclist.inspect}"
    exit 1
  end

  spec = Gem::Specification::load(speclist[0])
  RakeConfig = {
    :gemspec => spec,
    :gemspec_path => speclist[0],
    :package_dir => "pkg",
    :rcov_threshold => 80,
    :email => {
    :servers => [ {
    :server => "ruby-lang.org", 
    :helo => "gmail.com"
  } ],
    :announce_to_email => "ruby-talk@ruby-lang.org",
  },
  :files => {
    :code => spec.files.grep(%r{^lib/}),
    :test => spec.files.grep(%r{^spec/}),
    :docs => spec.files.grep(%r{^doc/})
  },
    :rubyforge => {
    :group_id => spec.rubyforge_project,
    :package_id => spec.name.downcase,
    :release_name => spec.full_name,
    :home_page => spec.homepage,
    :project_page => "http://rubyforge.org/project/#{spec.rubyforge_project}/"
  }
  }
end

directory "doc"
directory RakeConfig[:package_dir]

class SpecTask < RSpec::Core::RakeTask
  def initialize(name=:spec)
    super(name) do
      @ruby_opts = []
      @rspec_opts= %w{-f d --out last_run --color}
      @rcov_opts = %w{--exclude ^rcov/,[^/]*\.gemspec,^spec/,^spec_help/ --sort coverage --threshold 101 -o doc/coverage --xrefs --no-color} 
      @rcov = true
      @warning = false #bundler raises lots of warnings :/
      @failure_message = "Spec examples failed."
      @files_to_run = FileList['spec/**/*.rb']
      yield(self) if block_given?
    end
    task name => ".rspec"
  end

  attr_accessor :files_to_run

  def spec_command
    @spec_command ||= 
      begin
        cmd_parts = [*ruby_opts]
        cmd_parts << "-w" if warning?
        cmd_parts << "-S"
        cmd_parts << "bundle exec" if gemfile? unless skip_bundler

        if rcov
          cmd_parts += [*rcov_path]
          cmd_parts += ["-Ispec_help#{File::PATH_SEPARATOR}spec#{File::PATH_SEPARATOR}lib", *rcov_opts]
          cmd_parts += ["spec_help/spec_helper.rb", *files_to_run ]
          unless @rspec_opts.nil? or @rspec_opts.empty?
            cmd_parts << "--"
            cmd_parts += [*@rspec_opts]
          end
        else 
          cmd_parts += [*rspec_path]
          cmd_parts += [*@rspec_opts]
          cmd_parts += [*files_to_run]
        end


        cmd_parts.compact.join(" ").tap{|o| p o}
      end
  end
end

task :needs_root do
  unless Process::uid == 0
    fail "This task must be run as root"

    exit {
      unless (user = ENV['SUDO_USER']).nil?
        FileUtils::chown_R(user, ENV['SUDO_GID'].to_i, 'doc/coverage')
      end
    }
  end
end

desc "Run failing examples if any exist, otherwise, run the whole suite"
task :rspec => "rspec:quick"

namespace :rspec do
  file "doc/coverage/index.html" => FileList['spec/**/*.rb', 'lib/**/*.rb'] do
    Rake::Task['rspec:doc'].invoke
  end

  desc "Generate default .rspec file"
  file ".rspec" => ["Rakefile", RakeConfig[:gemspec_path]] do |t|
    options = [
      "--format documentation",
      "--out last_run",
    ]
    [%w{spec_help interpose}, %w{lib}, %w{spec_help}].map do|dir|
      options << "-I #{ File::join(File::dirname(__FILE__), *dir)}"
    end
    options << "--require spec_helper"
    File.open(t.name, "w") do |rspec|
      rspec.write(options.join("\n"))
    end
  end

  desc "Always run every spec"
  SpecTask.new(:all) 

  desc "Generate specifications documentation"
  SpecTask.new(:doc) do |t|
    t.rspec_opts = %w{-f s -o doc/Specifications}
    t.failure_message = "Failed generating specification docs"
    t.verbose = false
  end

  desc "Run specs with Ruby profiling"
  SpecTask.new(:profile) do |t|
    t.ruby_opts += %w{-rprofile}
  end

  desc "Run only failing examples"
  SpecTask.new(:quick) do |t|
    t.rspec_opts += %w{-f d --color}
    examples = []
    begin
      File.open("last_run", "r") do |fail_list|
        fail_list.lines.grep(%r{^\s*\d+\)\s*(.*)}) do |line|
          examples << $1.gsub(/'/){"[']"}
        end
      end
    rescue
    end
    unless examples.empty?
      t.rspec_opts << "--example"
      t.rspec_opts << "\"#{examples.join("|")}\""
    end
    t.rcov = false
    t.failure_message = "Spec examples failed."
  end

  desc "Run rspecs prior to a package publication"
  SpecTask.new(:check) do |t|
    t.rspec_opts = %w{--format p --out /dev/null}  
    t.failure_message = "Package does not conform to spec"
    t.verbose = false
  end

  desc "Open chromium to view RCov output"
  task :view_coverage => "doc/coverage/index.html" do |t|
    sh "/usr/bin/chromium doc/coverage/index.html"
  end
end

namespace :qa do
  desc "Confirm code quality - e.g. before shipping"
  task :sign_off => %w{verify_rcov compare:coverage_and_manifest}

  desc "Confirm a minimum code coverage"
  task :verify_rcov => "doc/coverage/index.html" do
    require 'nokogiri'

    doc = Nokogiri::parse(File::read('doc/coverage/index.html'))
    percentage = doc.xpath("//tt[@class='coverage_total']").first.content.to_f
    raise "Coverage must be at least #{RakeConfig[:rcov_threshold]} but was #{percentage}" if percentage < RakeConfig[:rcov_threshold]
    puts "Coverage is #{percentage}% (required: #{RakeConfig[:rcov_threshold]}%)"
  end

  namespace :compare do 
    desc "Ensure that all code files being shipped are covered"
    task :coverage_and_manifest => "doc/coverage/index.html" do
      require 'nokogiri'

      doc = Nokogiri::parse(File::read('doc/coverage/index.html'))
      covered_files = []
      doc.xpath("//table[@id='report_table']//td//a").each do |link|
        covered_files << link.content
      end
      not_listed = covered_files - RakeConfig[:files][:code]
      not_covered = RakeConfig[:files][:code] - covered_files
      unless not_listed.empty? and not_covered.empty?
        raise ["Covered files and gemspec manifest don't match:",
          "Not in gemspec: #{not_listed.inspect}",
        "Not covered: #{not_covered.inspect}"].join("\n")
      end
    end
  end
end

Rake::Gemcutter::Tasks.new(RakeConfig[:gemspec])
namespace :gem do
  task :push => %w{qa:sign_off package}
  task :install => [:needs_root, 'qa:sign_off']
  task :reinstall => [:needs_root, 'qa:sign_off']

  package = Rake::GemPackageTask.new(RakeConfig[:gemspec]) {|t|
    t.need_tar_gz = true
    t.need_tar_bz2 = true
  }
  task(:package).prerequisites.each do |package_type|
    file package_type => "rspec:check"
  end

  Rake::RDocTask.new(:docs) do |rd|
    rd.options += RakeConfig[:gemspec].rdoc_options
    rd.rdoc_dir = 'rubydoc'
    rd.rdoc_files.include(RakeConfig[:files][:code])
    rd.rdoc_files.include(RakeConfig[:files][:docs])
    rd.rdoc_files += (RakeConfig[:gemspec].extra_rdoc_files)
  end
  task :docs => ['rspec:doc']
end

task :gem => "gem:gem"

desc "Publish the gem and its documentation to Rubyforge and Gemcutter"
task :publish => ['publish:docs', 'publish:rubyforge', 'gem:push']

namespace :publish do
  desc 'Publish RDoc to RubyForge'
  task :docs => 'gem:docs' do
    config = YAML.load(File.read(File.expand_path("~/.rubyforge/user-config.yml")))
    host = "#{config["username"]}@rubyforge.org"
    remote_dir = "/var/www/gforge-projects/#{RakeConfig[:rubyforge][:group_id]}"
    local_dir = 'rubydoc'
    sh %{rsync -av --delete #{local_dir}/ #{host}:#{remote_dir}}
  end

  task :scrape_rubyforge do
    require 'rubyforge'
    forge = RubyForge.new
    forge.configure
    forge.scrape_project(RakeConfig[:rubyforge][:package_id])
  end

  desc "Publishes to RubyForge"
  task :rubyforge => ['qa:sign_off', 'gem:package', :docs, :scrape_rubyforge] do |t|
    require 'rubyforge'
    forge = RubyForge.new
    forge.configure
    files = [".gem", ".tar.gz", ".tar.bz2"].map do |extension|
      File::join(RakeConfig[:package_dir], RakeConfig[:gemspec].full_name) + extension
    end
    release = forge.lookup("release", RakeConfig[:rubyforge][:package_id])[RakeConfig[:rubyforge][:release_name]] rescue nil
    if release.nil?
      forge.add_release(RakeConfig[:rubyforge][:group_id], RakeConfig[:rubyforge][:package_id], RakeConfig[:rubyforge][:release_name], *files)
    else
      files.each do |file|
        forge.add_file(RakeConfig[:rubyforge][:group_id], RakeConfig[:rubyforge][:package_id], RakeConfig[:rubyforge][:release_name], file)
      end
    end
  end
end

def announcement
  changes = ""
  begin
    File::open("./Changelog", "r") do |changelog|
      changes = "Changes:\n\n"
      changes += changelog.read
    end
  rescue Exception
  end

  urls = "Project: #{RakeConfig[:rubyforge][:project_page]}\n" +
  "Homepage: #{RakeConfig[:rubyforge][:home_page]}"

  subject = "#{RakeConfig[:gemspec].name} #{RakeConfig[:gemspec].version} Released"
  title = "#{RakeConfig[:gemspec].name} version #{RakeConfig[:gemspec].version} has been released!"
  body = "#{RakeConfig[:gemspec].description}\n\n#{changes}\n\n#{urls}"

  return subject, title, body
end

desc 'Announce release on RubyForge and email'
task :press => ['press:rubyforge', 'press:email']
namespace :press do
  desc 'Post announcement to rubyforge.'
  task :rubyforge do
    require 'rubyforge'
    subject, title, body = announcement

    forge = RubyForge.new
    forge.configure
    forge.post_news(RakeConfig[:rubyforge][:group_id], subject, "#{title}\n\n#{body}")
    puts "Posted to rubyforge"
  end

  file "email.txt" do |t|
    subject, title, body= announcement

    mail = MailFactory.new
    mail.To = RakeConfig[:announce_to_email]
    mail.From = RakeConfig[:gemspec].email
    mail.Subject = "[ANN] " + subject
    mail.text = [title, body].join("\n\n")

    File.open(t.name, "w") do |mailfile|
      mailfile.write mail.to_s
    end
  end

  desc 'Generate email announcement file.'
  task :email => "email.txt" do
    require 'rubyforge'

    RakeConfig[:email_servers].each do |server_config|
      begin
        File::open("email.txt", "r") do |email|
          Net::SMTP.start(server_config[:server], 25, server_config[:helo], server_config[:username], server_config[:password]) do |smtp|
            smtp.data do |mta|
              mta.write(email.read)
            end
          end
        end
        break
      rescue Object => ex
        puts ex.message
      end
    end
  end
end
end
