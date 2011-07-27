module RSpecStepwise
  module ClassMethods
    #TODO: This is hacky and needs a more general solution
    #Something like cloning the current conf and having RSpec::Stepwise::config ?
    def suspend_transactional_fixtures
      if self.respond_to? :use_transactional_fixtures
        old_val = self.use_transactional_fixtures
        self.use_transactional_fixtures = false

        yield

        self.use_transactional_fixtures = old_val
      else
        yield
      end
    end

    def before(*args, &block)
      if args.first == :each
        puts "before blocks declared for steps are always treated as :all scope"
      end
      super
    end

    def after(*args, &block)
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

    def eval_before_alls(example_group_instance)
      super
      example_group_instance.example = whole_list_example
      world.run_hook_filtered(:before, :each, self, example_group_instance, example)
      ancestors.reverse.each { |ancestor| ancestor.run_hook(:before, :each, example_group_instance) }
    end

    def eval_around_eachs(example)
    end

    def eval_before_eachs(example)
    end

    def eval_after_eachs(example)
    end

    def eval_after_alls(example_group_instance)
      example_group_instance.example = whole_list_example
      ancestors.each { |ancestor| ancestor.run_hook(:after, :each, example_group_instance) }
      world.run_hook_filtered(:after, :each, self, example_group_instance, example)
      super
    end

    def whole_list_example
      RSpec::Core::Example.new(self, "step list", {})
    end

    def with_around_hooks(instance, &block)
      hooks = around_hooks_for(self)
      if hooks.empty?
        yield
      else
        hooks.reverse.inject(Example.procsy(metadata)) do |procsy, around_hook|
          Example.procsy(procsy.metadata) do
            instance.instance_eval_with_args(procsy, &around_hook)
          end
        end.call
      end
    end

    def perform_steps(name, *args, &customization_block)
      shared_block = world.shared_example_groups[name]
      raise "Could not find shared example group named \#{name.inspect}" unless shared_block

      module_eval_with_args(*args, &shared_block)
      module_eval(&customization_block) if customization_block
    end

    def run_examples(reporter)
      instance = new

      set_ivars(instance, before_all_ivars)

      instance.example = whole_list_example

      suspend_transactional_fixtures do
        with_around_hooks(instance) do
          filtered_examples.inject(true) do |success, example|
            break if RSpec.wants_to_quit
            unless success
              reporter.example_started(example)
              example.metadata[:pending] = true
              example.metadata[:execution_result][:pending_message] = "Previous step failed"
              example.metadata[:execution_result][:started_at] = Time.now
              example.instance_eval{ record_finished :pending, :pending_message => "Previous step failed" }
              reporter.example_pending(example)
              next
            end
            succeeded = instance.with_indelible_ivars do
              example.run(instance, reporter)
            end
            RSpec.wants_to_quit = true if fail_fast? && !succeeded
            success && succeeded
          end
        end
      end
    end
  end

  def with_indelible_ivars
    old_value, @ivars_indelible = @ivars_indelible, true
    result = yield
    @ivars_indelible = old_value
    result
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
