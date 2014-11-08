require 'rspec/support/spec'
require 'rspec/core'

class << RSpec
  attr_writer :configuration, :world
end

$rspec_core_without_stderr_monkey_patch = RSpec::Core::Configuration.new

class RSpec::Core::Configuration
  def self.new(*args, &block)
    super.tap do |config|
      # We detect ruby warnings via $stderr,
      # so direct our deprecations to $stdout instead.
      config.deprecation_stream = $stdout
    end
  end
end

module Sandboxing
  def sandboxed(&block)
    @orig_config = RSpec.configuration
    @orig_world  = RSpec.world
    @orig_example = RSpec.current_example
    new_config = RSpec::Core::Configuration.new
    new_config.expose_dsl_globally = false
    new_config.expecting_with_rspec = true
    new_config.include(RSpecStepwise, :stepwise => true)
    new_world  = RSpec::Core::World.new(new_config)
    RSpec.configuration = new_config
    RSpec.world = new_world
    object = Object.new
    object.extend(RSpec::Core::SharedExampleGroup)

    (class << RSpec::Core::ExampleGroup; self; end).class_exec do
      alias_method :orig_run, :run
      def run(reporter=nil)
        RSpec.current_example = nil
        orig_run(reporter || NullObject.new)
      end
    end

    RSpec::Mocks.with_temporary_scope do
      object.instance_exec(&block)
    end
  ensure
    (class << RSpec::Core::ExampleGroup; self; end).class_exec do
      remove_method :run
      alias_method :run, :orig_run
      remove_method :orig_run
    end

    RSpec.configuration = @orig_config
    RSpec.world = @orig_world
    RSpec.current_example = @orig_example
  end
end

RSpec.configure do |config|
  config.include Sandboxing
end

class NullObject
  private
  def method_missing(method, *args, &block)
    # ignore
  end
end
