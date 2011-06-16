require 'rspec-steps/stepwise'

module RSpec::Core
  module ObjectExtensions
    def steps(*args, &example_group_block)
      args << {} unless args.last.is_a?(Hash)
      RSpec::Core::ExampleGroup.steps(*args, &example_group_block).register
    end
  end
end
