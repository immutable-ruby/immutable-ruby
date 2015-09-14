require "spec_helper"

describe Immutable::Vector do
  describe "#to_list" do
    [
      [],
      ["A"],
      %w[A B C],
    ].each do |values|
      describe "on #{values.inspect}" do
        let(:vector) { V.new(values) }
        let(:list) { vector.to_list }

        it "returns a list" do
          list.is_a?(Immutable::List).should == true
        end

        describe "the returned list" do
          it "has the correct length" do
            list.size.should == values.size
          end

          it "contains all values" do
            list.to_a.should == values
          end
        end
      end
    end
  end
end