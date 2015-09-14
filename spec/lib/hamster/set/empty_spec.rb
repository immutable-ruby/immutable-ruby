require "spec_helper"

describe Immutable::Set do
  describe "#empty?" do
    [
      [[], true],
      [["A"], false],
      [%w[A B C], false],
      [[nil], false],
      [[false], false]
    ].each do |values, expected|
      describe "on #{values.inspect}" do
        it "returns #{expected.inspect}" do
          S[*values].empty?.should == expected
        end
      end
    end
  end

  describe ".empty" do
    it "returns the canonical empty set" do
      S.empty.should be_empty
      S.empty.object_id.should be(S[].object_id)
      S.empty.should be(Immutable::EmptySet)
    end

    context "from a subclass" do
      it "returns an empty instance of the subclass" do
        subclass = Class.new(Immutable::Set)
        subclass.empty.class.should be(subclass)
        subclass.empty.should be_empty
      end

      it "calls overridden #initialize when creating empty Set" do
        subclass = Class.new(Immutable::Set) do
          def initialize
            @variable = 'value'
          end
        end
        subclass.empty.instance_variable_get(:@variable).should == 'value'
      end
    end
  end
end