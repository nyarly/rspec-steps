module RSpecStepwise
  class ApatheticReporter < ::RSpec::Core::Reporter
    def initialize
      @examples = []
      @failed_examples = []
      @pending_examples = []
      @duration = @start = @load_time = nil
    end

    def notify(*args)
      #noop
    end
  end

  class WholeListExample < RSpec::Core::Example
    def initialize(example_group_class, descriptions, metadata)
      super
      @reporter = ApatheticReporter.new
      build_example_block
    end

    def start(reporter)
      super(@reporter)
    end

    def finish(reporter)
      super(@reporter)
    end

    def build_example_block
      #variables of concern: reporter, instance
      reporter = @reporter
      @example_block = proc do
        begin
          self.class.filtered_examples.inject(true) do |success, example|
            if RSpec.respond_to? :wants_to_quit
              break if RSpec.wants_to_quit
            else
              break if RSpec.world.wants_to_quit
            end
            example.extend StepExample
            unless success
              example.metadata[:pending] = true
              example.metadata[:execution_result][:pending_message] = "Previous step failed"
            end
            succeeded = with_indelible_ivars do
              example.run(self, reporter)
            end
            if self.class.fail_fast? && !succeeded
              if RSpec.respond_to? :wants_to_quit=
                RSpec.wants_to_quit = true
              else
                RSpec.world.wants_to_quit = true
              end
            end
            success && succeeded
          end
        end
      end
    end
  end

  module StepExample
    def run_before_each
      @example_group_class.run_before_step(self)
    rescue Object => ex
      puts "\n#{__FILE__}:#{__LINE__} => #{[ex, ex.backtrace].pretty_inspect}"
    end
    alias run_before_example run_before_each

    def run_after_each
      @example_group_class.run_after_step(self)
    end
    alias run_after_example run_after_each

    def with_around_hooks
      yield
    end
  end

  module ClassMethods
    #This is hacky and needs a more general solution
    #Something like cloning the current conf and having RSpec::Stepwise::config ?
    def suspend_transactional_fixtures
      if self.respond_to? :use_transactional_fixtures
        begin
          old_val = self.use_transactional_fixtures
          self.use_transactional_fixtures = false

          yield
        ensure
          self.use_transactional_fixtures = old_val
        end
      else
        yield
      end
    end

    def build_before_hook(options, &block)
      if defined? RSpec::Core::Hooks::BeforeHookExtension
        block.extend(RSpec::Core::Hooks::BeforeHookExtension).with(options)
      else
        RSpec::Core::Hooks::BeforeHook.new(block, options)
      end
    end

    def build_after_hook(options, &block)
      if defined? RSpec::Core::Hooks::AfterHookExtension
        block.extend(RSpec::Core::Hooks::AfterHookExtension).with(options)
      else
        RSpec::Core::Hooks::AfterHook.new(block, options)
      end
    end

    def _metadata_from_args(args)
      if RSpec::Core::Metadata.respond_to?(:build_hash_from)
        RSpec::Core::Metadata.build_hash_from(args)
      else
        build_metadata_hash_from(args)
      end
    end

    def before(*args, &block)
      if args.first == :step
        args.shift
        options = _metadata_from_args(args)
        return ((hooks[:before][:step] ||= []) << build_before_hook(options, &block))
      end
      if args.first == :each
        puts "before blocks declared for steps are always treated as :all scope"
      end
      super
    end

    def after(*args, &block)
      if args.first == :step
        args.shift
        options = _metadata_from_args(args)
        hooks[:after][:step] ||= []
        return (hooks[:after][:step].unshift build_after_hook(options, &block))
      end
      if args.first == :each
        puts "after blocks declared for steps are always treated as :all scope"
      end
      super
    end

    def around(*args, &block)
      if args.first == :each
        puts "around :each blocks declared for steps are treated as :all scope"
      end
      super
    end

    def example_synonym(named, desc=nil, *args, &block)
      unless desc.nil?
        desc = [named, desc].join(" ")
      end
      it(desc, *args, &block)
    end

    def when(*args, &block); example_synonym("when", *args, &block); end
    def then(*args, &block); example_synonym("then", *args, &block); end
    def next(*args, &block); example_synonym("next", *args, &block); end
    def step(*args, &block); example_synonym("step", *args, &block); end

    def run_step(example, hook, &sorting)
      groups = if respond_to?(:parent_groups)
                        parent_groups
                      else
                        ancestors
                      end

      if block_given?
        groups = yield groups
      end

      RSpec::Core::Hooks::HookCollection.new(groups.map {|a| a.hooks[hook][:step]}.flatten.compact).for(example).run
    end

    def run_before_step(example)
      run_step(example, :before)
    end

    def run_after_step(example)
      run_step(example, :after) do |groups|
        groups.reverse
      end
    end

    def perform_steps(name, *args, &customization_block)
      shared_block = nil
      if respond_to?(:world) and world.respond_to? :shared_example_groups
        shared_block = world.shared_example_groups[name]
      else
        if respond_to?(:shared_example_groups)
          shared_block = shared_example_groups[name]
        else
          shared_block = RSpec.world.shared_example_group_registry.find(parent_groups, name)
        end
      end
      raise "Could not find shared example group named #{name.inspect}" unless shared_block

      if respond_to? :module_exec
        module_exec(*args, &shared_block)
        module_exec(&customization_block) if customization_block
      else
        module_eval_with_args(*args, &shared_block)
        module_eval(&customization_block) if customization_block
      end
    end

    def run_examples(reporter)
      whole_list_example = WholeListExample.new(self, "step list", {})

      instance = new
      if respond_to? :before_context_ivars
        set_ivars(instance, before_context_ivars)
      else
        set_ivars(instance, before_all_ivars)
      end
      instance.example = whole_list_example if respond_to? :example=
      instance.reporter = reporter if respond_to? :reporter=

      result = suspend_transactional_fixtures do
        whole_list_example.run(instance, reporter)
      end

      unless whole_list_example.exception.nil?
        if fail_fast?
          if RSpec.respond_to? :wants_to_quit=
            RSpec.wants_to_quit = true
          else
            RSpec.world.wants_to_quit = true
          end
        end
        if respond_to? :fail_filtered_examples
          fail_filtered_examples(whole_list_example.exception, reporter)
        else
          ex = whole_list_example.exception
          for_filtered_examples(reporter) {|example| example.fail_with_exception(reporter, ex) }
        end
      end

      result
    end
  end

  attr_accessor :reporter

  def with_indelible_ivars
    old_value, @ivars_indelible = @ivars_indelible, true
    result = yield
    @ivars_indelible = old_value
    result
  rescue Object
    @ivars_indelible = old_value
    raise
  end

  def instance_variable_set(name, value)
    if !@ivars_indelible
      super
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
