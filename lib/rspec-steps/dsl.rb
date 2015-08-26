module RSpec::Steps
  def self.warnings
    @warnings ||= Hash.new do |h,warning|
      puts warning #should be warn, but RSpec complains
      h[warning] = true
    end
  end

  module DSL
    def steps(description, *args, &block)
      describer = Describer.new(description, *args, &block)

      describer.build_example_group
    end
  end
  extend DSL

  class Describer
    def initialize(description, *args, &block)
      @description = description
      @group_args = args
      @step_list = []
      @hooks = []
      instance_eval(&block)
    end
    attr_reader :description, :group_args, :step_list

    def step(description, *args, &action)
      @step_list << Step.new(description, *args, &action)
    end
    alias when step
    alias then step
    alias next step
    alias it step

    def before(kind, &callback)
      @hooks << Hook.new(:before, kind, callback)
    end

    def after(kind, &callback)
      @hooks << Hook.new(:after, kind, callback)
    end

    def around(&callback)
      @hooks << Hook.new(:around, kind, callback)
    end
  end

  class Builder
    def initialize(describer)
      @describer = describer
    end
    attr_reader :describer

    def build_example_group(describer)
      step_list = describer.step_list
      hook_list = describer.hooks
      RSpec.describe(describer.description, describer.group_args) do
        hook_list.each do |hook|
          hook.define_on(self)
        end
        step_list.each do |step|
          step.define_on(step_list, self)
        end
      end
    end
  end

  class StepList
    include Enumerable

    def initialize
      @steps = []
      @run = false
    end

    def add(step)
      @steps << step
    end
    alias << add

    def each(&block)
      @steps.each(&block)
    end

    def run_only_once(context_example)
      return if @run
      @run = true
      last_run = nil
      @steps.drop_while do |step|
        last_run = step
        step.run_inside(context_example)
        step.has_executed_successfully?
      end.each do |step|
        step.failed_step = last_run
      end
    end
  end

  class Step
    Nothing = BasicObject.new.freeze

    def initialize(description, *args, &action)
      @description = description
      @args = args
      @action = action
      @exception = Nothing
      @result = Nothing
      @failed_step = nil
    end
    attr_reader :description, :args, :action
    attr_accessor :failed_step

    def define_on(step_list, example_group)
      step = self
      example_group.it description do |in_context|
        step_list.run_only_once(in_context)
        pending if step.is_after_failed_step?
        expect(step).to have_executed_successfully
      end
    end

    def run_inside(example)
      @result = example.instance_eval(action)
    rescue BasicObject => ex
      @exception = ex
    end

    def has_executed_successfully?
      if @exception == Nothing
        true
      else
        raise @exception
      end
    end

    def is_after_failed_step?
      !!@failed_step
    end
  end

  Hook = Struct.new(:type, :kind, :action)
  class Hook
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
        example_group.before kind, &action
      when :after
        example_group.after kind, &action
      when :around
        example_group.around kind, &action
      end
    end
  end
end
