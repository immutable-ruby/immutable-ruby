require 'set'
require 'immutable/hash'
require 'immutable/set'
require 'immutable/vector'
require 'immutable/sorted_set'
require 'immutable/list'
require 'immutable/deque'

module Immutable
  class << self

    # Create a nested Immutable data structure from a nested Ruby object `obj`.
    # This method recursively "walks" the Ruby object, converting Ruby `Hash` to
    # {Immutable::Hash}, Ruby `Array` to {Immutable::Vector}, Ruby `Set` to
    # {Immutable::Set}, and Ruby `SortedSet` to {Immutable::SortedSet}.  Other
    # objects are left as-is.
    #
    # @example
    #   h = Immutable.from({ "a" => [1, 2], "b" => "c" })
    #   # => Immutable::Hash["a" => Immutable::Vector[1, 2], "b" => "c"]
    #
    # @return [Hash, Vector, Set, SortedSet, Object]
    def from(obj)
      case obj
      when ::Hash
        res = obj.map { |key, value| [from(key), from(value)] }
        Immutable::Hash.new(res)
      when Immutable::Hash
        obj.map { |key, value| [from(key), from(value)] }
      when ::Array
        res = obj.map { |element| from(element) }
        Immutable::Vector.new(res)
      when ::Struct
        from(obj.to_h)
      when ::SortedSet
        # This clause must go before ::Set clause, since ::SortedSet is a ::Set.
        res = obj.map { |element| from(element) }
        Immutable::SortedSet.new(res)
      when ::Set
        res = obj.map { |element| from(element) }
        Immutable::Set.new(res)
      when Immutable::Vector, Immutable::Set, Immutable::SortedSet
        obj.map { |element| from(element) }
      else
        obj
      end
    end

    # Create a Ruby object from Immutable data. This method recursively "walks"
    # the Immutable object, converting {Immutable::Hash} to Ruby `Hash`,
    # {Immutable::Vector} and {Immutable::Deque} to Ruby `Array`, {Immutable::Set}
    # to Ruby `Set`, and {Immutable::SortedSet} to Ruby `SortedSet`.  Other
    # objects are left as-is.
    #
    # @example
    #   h = Immutable.to_ruby(Immutable.from({ "a" => [1, 2], "b" => "c" }))
    #   # => { "a" => [1, 2], "b" => "c" }
    #
    # @return [::Hash, ::Array, ::Set, ::SortedSet, Object]
    def to_ruby(obj)
      case obj
      when Immutable::Hash, ::Hash
        obj.each_with_object({}) { |keyval, hash| hash[to_ruby(keyval[0])] = to_ruby(keyval[1]) }
      when Immutable::Vector, ::Array
        obj.each_with_object([]) { |element, arr| arr << to_ruby(element) }
      when Immutable::Set, ::Set
        obj.each_with_object(::Set.new) { |element, set| set << to_ruby(element) }
      when Immutable::SortedSet, ::SortedSet
        obj.each_with_object(::SortedSet.new) { |element, set| set << to_ruby(element) }
      when Immutable::Deque
        obj.to_a.tap { |arr| arr.map! { |element| to_ruby(element) }}
      else
        obj
      end
    end
  end
end
