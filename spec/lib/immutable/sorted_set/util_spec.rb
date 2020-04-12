require "spec_helper"

describe Immutable::SortedSet do
  # Utility method used for filtering out duplicate objects, with equality
  #   determined by comparator
  describe ".uniq_by_comparator!" do
    it "can handle empty arrays" do
      array = []
      SS.uniq_by_comparator!(array, ->(x,y) { x <=> y })
      expect(array).to be_empty
    end

    it "can handle arrays with 1 element" do
      array = [1]
      SS.uniq_by_comparator!(array, ->(x,y) { x <=> y })
      expect(array).to eq([1])
    end

    it "can handle arrays with 2 elements and no dupes" do
      array = [1, 2]
      SS.uniq_by_comparator!(array, ->(x,y) { x <=> y })
      expect(array).to eq([1, 2])
    end

    it "can handle arrays with 2 elements and dupes" do
      array = [1, 1]
      SS.uniq_by_comparator!(array, ->(x,y) { x <=> y })
      expect(array).to eq([1])
    end

    it "can handle arrays with lots of elements" do
      100.times do
        array1 = rand(100).times.collect { rand(100) }.sort
        array2 = array1.dup.uniq
        SS.uniq_by_comparator!(array1, ->(x,y) { x <=> y })
        expect(array1).to eq(array2)
      end
    end

    it "works with funny comparators" do
      # let's work in modulo arithmetic
      comparator = ->(x,y) { (x % 7) <=> (y % 7) }
      array = [21, 1, 8, 1, 9, 10, 3, 5, 6, 20] # this is "sorted" (modulo 7)
      SS.uniq_by_comparator!(array, comparator)
      expect(array).to eq([21, 1, 9, 10, 5, 6])
    end
  end
end
