# It should be possible to require any one Immutable structure,
# without loading all the others

immutable_lib_dir = File.join(File.dirname(__FILE__), "..", "..", 'lib')

describe :Immutable do
  describe :Hash do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{immutable_lib_dir}'); require 'immutable/hash'; Immutable::Hash.new"}).should be(true)
    end
  end

  describe :Set do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{immutable_lib_dir}'); require 'immutable/set'; Immutable::Set.new"}).should be(true)
    end
  end

  describe :Vector do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{immutable_lib_dir}'); require 'immutable/vector'; Immutable::Vector.new"}).should be(true)
    end
  end

  describe :List do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{immutable_lib_dir}'); require 'immutable/list'; Immutable::List[]"}).should be(true)
    end
  end

  describe :SortedSet do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{immutable_lib_dir}'); require 'immutable/sorted_set'; Immutable::SortedSet.new"}).should be(true)
    end
  end

  describe :Deque do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{immutable_lib_dir}'); require 'immutable/deque'; Immutable::Deque.new"}).should be(true)
    end
  end
end