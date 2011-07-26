require 'rspec-steps/stepwise'

module RSpec::Core
  module ObjectExtensions
    def steps(*args, &example_group_block)
      RSpec::Core::ExampleGroup.steps(*args, &example_group_block).register
    end

    alias :shared_steps :shared_context
    alias :steps_shared_as :share_as
  end
end
