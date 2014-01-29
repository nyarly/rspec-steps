require 'rspec-steps/duckpunch/example-group'
require 'rspec-steps/stepwise'
require 'rspec/core/shared_example_group'

module RSpec::Core::SharedExampleGroup
  alias :shared_steps :share_examples_for
  alias :steps_shared_as :share_as
end
