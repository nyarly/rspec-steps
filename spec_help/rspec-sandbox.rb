require 'rspec/core'

class NullObject
  private
  def method_missing(method, *args, &block)
    # ignore
  end
end

def sandboxed(&block)
  @orig_config = RSpec.configuration
  @orig_world  = RSpec.world
  new_config = RSpec::Core::Configuration.new
  new_world  = RSpec::Core::World.new(new_config)
  RSpec.instance_variable_set(:@configuration, new_config)
  RSpec.instance_variable_set(:@world, new_world)

  load 'rspec-steps/duckpunch/example-group.rb'

  object = Object.new
  object.extend(RSpec::Core::SharedExampleGroup)
  object.extend(RSpec::Steps::DSL)
  object.extend(RSpec::Core::DSL)

  (class << RSpec::Core::ExampleGroup; self; end).class_eval do
    alias_method :orig_run, :run
    def run(reporter=nil)
      @orig_mock_space = RSpec::Mocks::space
      RSpec::Mocks::space = RSpec::Mocks::Space.new
      orig_run(reporter || NullObject.new)
    ensure
      RSpec::Mocks::space = @orig_mock_space
    end
  end

  object.instance_eval(&block)
ensure
  (class << RSpec::Core::ExampleGroup; self; end).class_eval do
    remove_method :run
    alias_method :run, :orig_run
    remove_method :orig_run
  end

  RSpec.instance_variable_set(:@configuration, @orig_config)
  RSpec.instance_variable_set(:@world, @orig_world)
end
