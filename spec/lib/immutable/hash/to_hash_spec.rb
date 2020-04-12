require "spec_helper"

describe Immutable::Hash do
  [:to_hash, :to_h].each do |method|
    describe "##{method}" do
      it "converts an empty Immutable::Hash to an empty Ruby Hash" do
        H.empty.send(method).should eql({})
      end

      it "converts a non-empty Immutable::Hash to a Hash with the same keys and values" do
        H[a: 1, b: 2].send(method).should eql({a: 1, b: 2})
      end

      it "doesn't modify the receiver" do
        hash = H[a: 1, b: 2]
        hash.send(method)
        hash.should eql(H[a: 1, b: 2])
      end
    end
  end
end
