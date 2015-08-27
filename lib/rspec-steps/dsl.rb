module RSpec::Steps
  def self.warnings
    @warnings ||= Hash.new do |h,warning|
      puts warning #should be warn, but RSpec complains
      h[warning] = true
    end
  end

  module DSL
    def steps(*args, &block)
      describer = Describer.new(*args, &block)
      builder = Builder.new(describer)

      builder.build_example_group
    end

    def shared_steps(*args, &block)
      name = args.first
      raise "shared step lists need a String for a name" unless name.is_a? String
      raise "there is already a step list named #{name}" if SharedSteps.has_key?(name)
      SharedSteps[name] = Describer.new(*args, &block)
    end
  end
  extend DSL

  SharedSteps = {}

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

  class Builder
    def initialize(describer)
      @describer = describer
    end
    attr_reader :describer

    def build_example_group
      step_list = describer.step_list
      hook_list = describer.hooks
      RSpec.describe(*describer.group_args) do
        hook_list.each do |hook|
          hook.define_on(self)
        end
        step_list.each do |step|
          step.define_on(step_list, self)
        end
      end
    end
  end

  class StepResult < Struct.new(:step, :result, :exception, :failed_step)
    def failed?
      return (!exception.nil?)
    end

    def has_executed_successfully?
      if failed_step.nil?
        if exception.nil?
          true
        else
          raise exception
        end
      else
        raise failed_step.exception
      end
    end

    def is_after_failed_step?
      !!failed_step
    end
  end

  class StepList
    include Enumerable

    def initialize
      @steps = []
      @results = nil
    end
    attr_accessor :steps

    def add(step)
      @steps << step
    end
    alias << add

    def +(other)
      result = StepList.new
      result.steps = steps + other.steps
      result
    end

    def each(&block)
      @steps.each(&block)
    end

    def result_for(step)
      @results[step]
    end

    def run_only_once(context_example)
      return unless @results.nil?
      failed_step = nil
      @results = Hash[ @steps.map do |step|
        [
          step,
          if failed_step.nil?
            result = capture_result(step, context_example)
            if result.failed?
              failed_step = result
            end
            result
          else
            StepResult.new(step, nil, nil, failed_step)
          end
        ]
      end ]
    end

    def capture_result(step, context_example)
      StepResult.new(step, step.run_inside(context_example), nil, nil)
    rescue BasicObject => ex
      StepResult.new(step, nil, ex, nil)
    end
  end

  class Step
    def initialize(*args, &action)
      @args = args
      @action = action
      @failed_step = nil
    end
    attr_reader  :args, :action
    attr_accessor :failed_step

    def define_on(step_list, example_group)
      step = self
      example_group.it(*args) do |in_context|
        step_list.run_only_once(in_context)
        result = step_list.result_for(step)
        pending if result.is_after_failed_step?
        expect(result).to have_executed_successfully
      end
    end

    def run_inside(example)
      example.instance_eval(&action)
    end

  end

  class Hook < Struct.new(:type, :kind, :action)
    def rspec_kind
      case kind
      when :each
        warn_about_promotion(type)
        :all
      when :step
        :each
      else
        kind
      end
    end

    def warn_about_promotion(scope_name)
      RSpec::Steps.warnings[
        "#{scope_name} :each blocks declared for steps are always treated as " +
        ":all scope (it's possible you want #{scope_name} :step)"]
    end

    def define_on(example_group)
      case type
      when :before
        example_group.before rspec_kind, &action
      when :after
        example_group.after rspec_kind, &action
      when :around
        example_group.around rspec_kind, &action
      end
    end
  end
end
