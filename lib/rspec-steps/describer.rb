require 'rspec-steps/dsl'
require 'rspec-steps/step'
require 'rspec-steps/hook'
require 'rspec-steps/step-list'

module RSpec::Steps

  class Let < Struct.new(:name, :block)
    def define_on(step_list, group)
      name = self.name
      step_list.add_let(name, block)

      group.let(name) do
        step_list.let_memo(name, self)
      end
    end
  end

  class LetBang < Let
    def define_on(step_list, group)
      super

      step_list.add_let_bang(name)
    end
  end

  class Describer
    def initialize(args, metadata, &block)
      @group_args = args
      @metadata = {}
      if @group_args.last.is_a? Hash
        @metadata = @group_args.pop
      end
      @metadata = metadata.merge(@metadata)
      @step_list = StepList.new
      @hooks = []
      @let_list = []
      instance_eval(&block)
    end
    attr_reader  :group_args, :let_list, :step_list, :hooks, :metadata

    def step(*args, &action)
      metadata = {}
      if args.last.is_a? Hash
        metadata = args.pop
      end

      metadata = {
        :caller => caller
      }.merge(metadata)

      @step_list << Step.new(metadata, args, action)
    end
    alias when step
    alias then step
    alias next step
    alias it step

    def shared_steps(*args, &block)
      name = args.first
      raise "shared step lists need a String for a name" unless name.is_a? String
      raise "there is already a step list named #{name}" if SharedSteps.has_key?(name)
      SharedSteps[name] = Describer.new(args, {:caller => caller}, &block)
    end

    def perform_steps(name)
      describer = SharedSteps.fetch(name)
      @hooks += describer.hooks
      @step_list += describer.step_list
    end

    def let(name, &block)
      @let_list << Let.new(name, block)
    end

    def let!(name, &block)
      @let_list << LetBang.new(name, block)
    end

    def skip(*args)
      #noop
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
