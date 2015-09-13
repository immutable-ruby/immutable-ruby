require "spec_helper"
require "hamster/sorted_set"

describe Immutable::SortedSet do
  describe "#sample" do
    let(:sorted_set) { Immutable::SortedSet.new(1..10) }

    it "returns a randomly chosen item" do
      chosen = 100.times.map { sorted_set.sample }
      chosen.each { |item| sorted_set.include?(item).should == true }
      sorted_set.each { |item| chosen.include?(item).should == true }
    end
  end
end
