# It should be possible to require any one Hamster structure,
# without loading all the others

hamster_lib_dir = File.join(File.dirname(__FILE__), "..", "..", 'lib')

describe :Hamster do
  describe :Hash do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{hamster_lib_dir}'); require 'hamster/hash'; Immutable::Hash.new"}).should be(true)
    end
  end

  describe :Set do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{hamster_lib_dir}'); require 'hamster/set'; Immutable::Set.new"}).should be(true)
    end
  end

  describe :Vector do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{hamster_lib_dir}'); require 'hamster/vector'; Immutable::Vector.new"}).should be(true)
    end
  end

  describe :List do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{hamster_lib_dir}'); require 'hamster/list'; Immutable::List[]"}).should be(true)
    end
  end

  describe :SortedSet do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{hamster_lib_dir}'); require 'hamster/sorted_set'; Immutable::SortedSet.new"}).should be(true)
    end
  end

  describe :Deque do
    it "can be loaded separately" do
      system(%{ruby -e "$:.unshift('#{hamster_lib_dir}'); require 'hamster/deque'; Immutable::Deque.new"}).should be(true)
    end
  end
end