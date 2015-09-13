require "spec_helper"
require "hamster/hash"

describe Immutable::Hash do
  describe "#sample" do
    let(:hash) { Immutable::Hash.new((:a..:z).zip(1..26)) }

    it "returns a randomly chosen item" do
      chosen = 250.times.map { hash.sample }.sort.uniq
      chosen.each { |item| hash.include?(item[0]).should == true }
      hash.each { |item| chosen.include?(item).should == true }
    end
  end
end
