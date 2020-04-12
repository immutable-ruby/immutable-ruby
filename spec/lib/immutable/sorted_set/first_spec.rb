require "spec_helper"

describe Immutable::SortedSet do
  describe "#first" do
    [
      [[], nil],
      [["A"], "A"],
      [%w[A B C], "A"],
      [%w[Z Y X], "X"]
    ].each do |values, expected|
      context "on #{values.inspect}" do
        it "returns #{expected.inspect}" do
          SS[*values].first.should eql(expected)
        end
      end
    end
  end
end
