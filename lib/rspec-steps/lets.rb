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
end
