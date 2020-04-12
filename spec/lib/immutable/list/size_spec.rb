require 'spec_helper'

describe Immutable::List do
  [:size, :length].each do |method|
    describe "##{method}" do
      context 'on a really big list' do
        it "doesn't run out of stack" do
          -> { BigList.size }.should_not raise_error
        end
      end

      [
        [[], 0],
        [['A'], 1],
        [%w[A B C], 3],
      ].each do |values, expected|
        context "on #{values.inspect}" do
          it "returns #{expected.inspect}" do
            L[*values].send(method).should == expected
          end
        end
      end
    end
  end
end
