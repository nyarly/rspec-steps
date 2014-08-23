require 'rspec/core'
require 'rspec-steps/stepwise'

if RSpec.configuration.respond_to? :alias_example_group_to
  RSpec.configuration.alias_example_group_to :steps, :stepwise => true
else
  module RSpec::Steps
    module DSL
      def steps(*args, &block)
        options =
          if args.last.is_a?(Hash)
            args.pop
          else
            {}
          end
        options[:stepwise] = true
        options[:caller] ||= caller
        args.push(options)

        describe(*args, &block)
      end
    end
  end

  [RSpec::Core::ExampleGroup, RSpec, self].each do |mod|
    mod.extend RSpec::Steps::DSL
  end
  Module::send(:include, RSpec::Steps::DSL)
end

RSpec::configure do |config|
  config.include(RSpecStepwise, :stepwise => true)
end
