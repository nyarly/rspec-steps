require 'rspec-steps'
require 'rspec-sandbox'

describe RSpec::Core::ExampleGroup, "defined as stepwise" do
  describe "::steps" do
    it "should create an ExampleGroup that includes RSpec::Stepwise" do
      group = nil
      sandboxed do
        group = steps "Test Steps" do
        end
      end
      (class << group; self; end).included_modules.should include(RSpecStepwise::ClassMethods)
    end
  end

  describe "with Stepwise included" do
    it "should retain instance variables between steps" do
      group = nil
      sandboxed do
        group = steps "Test Steps" do
          it("sets @a"){ @a = 1 }
          it("reads @a"){ @a.should == 1}
        end
        group.run
      end

      group.examples.each do |example|
        example.metadata[:execution_result][:status].should == 'passed'
      end
    end

    it "should mark later examples as failed if a before hook fails" do
      group = nil
      exception = Exception.new "Testing Error"

      sandboxed do
        group = steps "Test Steps" do
          before { raise exception }
          it { 1.should == 1 }
          it { 1.should == 1 }
        end
        group.run
      end

      group.examples.each do |example|
        example.metadata[:execution_result][:status].should == 'failed'
        example.metadata[:execution_result][:exception].should == exception
      end
    end

    it "should mark later examples as pending if one fails" do
      group = nil
      sandboxed do
        group = steps "Test Steps" do
          it { fail "All others fail" }
          it { 1.should == 1 }
        end
        group.run
      end

      group.examples[1].metadata[:pending].should be_true
    end

    it "should allow nested steps", :pending => "Not really" do
      group = nil
      sandboxed do
        group = steps "Test Steps" do
          steps "Nested" do
            it { @a = 1 }
            it { @a.should == 1}
          end
        end
        group.run
      end

      group.children[0].examples.each do |example|
        example.metadata[:execution_result][:status].should == 'passed'
      end
      group.children[0].should have(2).examples
    end

    it "should not allow nested normal contexts" do
      pending "A correct approach - in the meantime, this behavior is undefined"
      expect {
        sandboxed do
        steps "Basic" do
          describe "Not allowed" do
          end
        end
        end
      }.to raise_error
    end
  end
end
