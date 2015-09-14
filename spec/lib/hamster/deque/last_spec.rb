require "spec_helper"

describe Immutable::Deque do
  describe "#last" do
    [
      [[], nil],
      [["A"], "A"],
      [%w[A B C], "C"],
    ].each do |values, expected|
      context "on #{values.inspect}" do
        it "returns #{expected.inspect}" do
          D[*values].last.should eql(expected)
        end
      end
    end
  end
end