require "spec_helper"

describe Immutable::Set do
  describe ".set" do
    context "with no values" do
      it "returns the empty set" do
        S.empty.should be_empty
        S.empty.should equal(Immutable::EmptySet)
      end
    end

    context "with a list of values" do
      it "is equivalent to repeatedly using #add" do
        S["A", "B", "C"].should eql(S.empty.add("A").add("B").add("C"))
      end
    end
  end
end
