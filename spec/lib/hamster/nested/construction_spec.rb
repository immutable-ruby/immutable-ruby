require "spec_helper"
require "hamster/nested"
require "hamster/deque"
require "set"

describe Immutable do
  expectations = [
    # [Ruby, Immutable]
    [ { "a" => 1,
        "b" => [2, {"c" => 3}, 4],
        "d" => ::Set.new([5, 6, 7]),
        "e" => {"f" => 8, "g" => 9},
        "h" => Regexp.new("ijk"),
        "l" => ::SortedSet.new([1, 2, 3]) },
      Immutable::Hash[
        "a" => 1,
        "b" => Immutable::Vector[2, Immutable::Hash["c" => 3], 4],
        "d" => Immutable::Set[5, 6, 7],
        "e" => Immutable::Hash["f" => 8, "g" => 9],
        "h" => Regexp.new("ijk"),
        "l" => Immutable::SortedSet.new([1, 2, 3])] ],
    [ {}, Immutable::Hash[] ],
    [ {"a" => 1, "b" => 2, "c" => 3}, Immutable::Hash["a" => 1, "b" => 2, "c" => 3] ],
    [ [], Immutable::Vector[] ],
    [ [1, 2, 3], Immutable::Vector[1, 2, 3] ],
    [ ::Set.new, Immutable::Set[] ],
    [ ::Set.new([1, 2, 3]), Immutable::Set[1, 2, 3] ],
    [ ::SortedSet.new, Immutable::SortedSet[] ],
    [ ::SortedSet.new([1, 2, 3]), Immutable::SortedSet[1, 2, 3] ],
    [ 42, 42 ],
    [ STDOUT, STDOUT ]
  ]

  describe ".from" do
    expectations.each do |input, expected_result|
      context "with #{input.inspect} as input" do
        it "should return #{expected_result.inspect}" do
          Immutable.from(input).should eql(expected_result)
        end
      end
    end

    context "with mixed object" do
      it "should return Immutable data" do
        input = {
          "a" => "b",
          "c" => {"d" => "e"},
          "f" => Immutable::Vector["g", "h", []],
          "i" => Immutable::Hash["j" => {}, "k" => Immutable::Set[[], {}]] }
        expected_result = Immutable::Hash[
          "a" => "b",
          "c" => Immutable::Hash["d" => "e"],
          "f" => Immutable::Vector["g", "h", Immutable::EmptyVector],
          "i" => Immutable::Hash["j" => Immutable::EmptyHash, "k" => Immutable::Set[Immutable::EmptyVector, Immutable::EmptyHash]] ]
        Immutable.from(input).should eql(expected_result)
      end
    end
  end

  describe ".to_ruby" do
    expectations.each do |expected_result, input|
      context "with #{input.inspect} as input" do
        it "should return #{expected_result.inspect}" do
          Immutable.to_ruby(input).should eql(expected_result)
        end
      end
    end

    context "with Immutable::Deque[] as input" do
      it "should return []" do
        Immutable.to_ruby(Immutable::Deque[]).should eql([])
      end
    end

    context "with Immutable::Deque[Immutable::Hash[\"a\" => 1]] as input" do
      it "should return [{\"a\" => 1}]" do
        Immutable.to_ruby(Immutable::Deque[Immutable::Hash["a" => 1]]).should eql([{"a" => 1}])
      end
    end

    context "with mixed object" do
      it "should return Ruby data structures" do
        input = Immutable::Hash[
          "a" => "b",
          "c" => {"d" => "e"},
          "f" => Immutable::Vector["g", "h"],
          "i" => {"j" => Immutable::EmptyHash, "k" => Set.new([Immutable::EmptyVector, Immutable::EmptyHash])}]
        expected_result = {
          "a" => "b",
          "c" => {"d" => "e"},
          "f" => ["g", "h"],
          "i" => {"j" => {}, "k" => Set.new([[], {}])} }
        Immutable.to_ruby(input).should eql(expected_result)
      end
    end
  end
end
