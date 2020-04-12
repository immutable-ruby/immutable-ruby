require "spec_helper"

describe Immutable::Vector do
  describe "#first" do
    [
      [[], nil],
      [["A"], "A"],
      [%w[A B C], "A"],
      [(1..32), 1],
    ].each do |values, expected|
      describe "on #{values.inspect}" do
        it "returns #{expected.inspect}" do
          V[*values].first.should == expected
        end
      end
    end
  end
end
