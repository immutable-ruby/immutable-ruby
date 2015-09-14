require "spec_helper"

describe Immutable::Hash do
  describe "#values_at" do
    it "returns a vector of values for the given keys" do
      h = H[:a => 9, :b => 'a', :c => -10, :d => nil]
      h.values_at.should be_kind_of(Immutable::Vector)
      h.values_at.should eql(V.empty)
      h.values_at(:a, :d, :b).should be_kind_of(Immutable::Vector)
      h.values_at(:a, :d, :b).should eql(V[9, nil, 'a'])
    end
  end
end