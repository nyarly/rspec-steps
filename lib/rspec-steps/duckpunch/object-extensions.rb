require 'rspec-steps/duckpunch/example-group'
require 'rspec-steps/stepwise'
require 'rspec/core/shared_example_group'

module RSpec::Core::SharedExampleGroup
  alias shared_steps shared_examples
  if respond_to? :share_as
    alias steps_shared_as share_as
  end
end

[self, RSpec].each do |thing|
  if thing.respond_to? :shared_examples and not thing.respond_to? :shared_steps
    thing.instance_exec do
      alias shared_steps shared_examples
    end
  end
end
