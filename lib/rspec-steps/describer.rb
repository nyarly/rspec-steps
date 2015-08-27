require 'rspec-steps/dsl'
require 'rspec-steps/step'
require 'rspec-steps/hook'
require 'rspec-steps/step-list'

module RSpec::Steps
  class Describer
    def initialize(*args, &block)
      @group_args = args
      @step_list = StepList.new
      @hooks = []
      instance_eval(&block)
    end
    attr_reader  :group_args, :step_list, :hooks

    def step(*args, &action)
      @step_list << Step.new(*args, &action)
    end
    alias when step
    alias then step
    alias next step
    alias it step

    def shared_steps(*args, &block)
      name = args.first
      raise "shared step lists need a String for a name" unless name.is_a? String
      raise "there is already a step list named #{name}" if SharedSteps.has_key?(name)
      SharedSteps[name] = Describer.new(*args, &block)
    end

    def perform_steps(name)
      describer = SharedSteps.fetch(name)
      @hooks += describer.hooks
      @step_list += describer.step_list
    end

    def before(kind = :all, &callback)
      @hooks << Hook.new(:before, kind, callback)
    end

    def after(kind = :all, &callback)
      @hooks << Hook.new(:after, kind, callback)
    end

    def around(kind = :all, &callback)
      @hooks << Hook.new(:around, kind, callback)
    end
  end
end
