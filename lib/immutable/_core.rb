require 'immutable/undefined'
require 'immutable/enumerable'
require 'immutable/trie'
require 'immutable/sorted_set'
require 'set'

module Immutable

  # An `Immutable::Hash` maps a set of unique keys to corresponding values, much
  # like a dictionary maps from words to definitions. Given a key, it can store
  # and retrieve an associated value in constant time. If an existing key is
  # stored again, the new value will replace the old. It behaves much like
  # Ruby's built-in Hash, which we will call RubyHash for clarity. Like
  # RubyHash, two keys that are `#eql?` to each other and have the same
  # `#hash` are considered identical in an `Immutable::Hash`.
  #
  # An `Immutable::Hash` can be created in a couple of ways:
  #
  #     Immutable::Hash.new(font_size: 10, font_family: 'Arial')
  #     Immutable::Hash[first_name: 'John', last_name: 'Smith']
  #
  # Any `Enumerable` object which yields two-element `[key, value]` arrays
  # can be used to initialize an `Immutable::Hash`:
  #
  #     Immutable::Hash.new([[:first_name, 'John'], [:last_name, 'Smith']])
  #
  # Key/value pairs can be added using {#put}. A new hash is returned and the
  # existing one is left unchanged:
  #
  #     hash = Immutable::Hash[a: 100, b: 200]
  #     hash.put(:c, 500) # => Immutable::Hash[:a => 100, :b => 200, :c => 500]
  #     hash              # => Immutable::Hash[:a => 100, :b => 200]
  #
  # {#put} can also take a block, which is used to calculate the value to be
  # stored.
  #
  #     hash.put(:a) { |current| current + 200 } # => Immutable::Hash[:a => 300, :b => 200]
  #
  # Since it is immutable, all methods which you might expect to "modify" a
  # `Immutable::Hash` actually return a new hash and leave the existing one
  # unchanged. This means that the `hash[key] = value` syntax from RubyHash
  # *cannot* be used with `Immutable::Hash`.
  #
  # Nested data structures can easily be updated using {#update_in}:
  #
  #     hash = Immutable::Hash["a" => Immutable::Vector[Immutable::Hash["c" => 42]]]
  #     hash.update_in("a", 0, "c") { |value| value + 5 }
  #     # => Immutable::Hash["a" => Immutable::Hash["b" => Immutable::Hash["c" => 47]]]
  #
  # While an `Immutable::Hash` can iterate over its keys or values, it does not
  # guarantee any specific iteration order (unlike RubyHash). Methods like
  # {#flatten} do not guarantee the order of returned key/value pairs.
  #
  # Like RubyHash, an `Immutable::Hash` can have a default block which is used
  # when looking up a key that does not exist. Unlike RubyHash, the default
  # block will only be passed the missing key, without the hash itself:
  #
  #     hash = Immutable::Hash.new { |missing_key| missing_key * 10 }
  #     hash[5] # => 50
  class Hash
    include Immutable::Enumerable

    class << self
      # Create a new `Hash` populated with the given key/value pairs.
      #
      # @example
      #   Immutable::Hash["A" => 1, "B" => 2] # => Immutable::Hash["A" => 1, "B" => 2]
      #   Immutable::Hash[["A", 1], ["B", 2]] # => Immutable::Hash["A" => 1, "B" => 2]
      #
      # @param pairs [::Enumerable] initial content of hash. An empty hash is returned if not provided.
      # @return [Hash]
      def [](pairs = nil)
        (pairs.nil? || pairs.empty?) ? empty : new(pairs)
      end

      # Return an empty `Hash`. If used on a subclass, returns an empty instance
      # of that class.
      #
      # @return [Hash]
      def empty
        @empty ||= new
      end

      # "Raw" allocation of a new `Hash`. Used internally to create a new
      # instance quickly after obtaining a modified {Trie}.
      #
      # @return [Hash]
      # @private
      def alloc(trie = EmptyTrie, block = nil)
        obj = allocate
        obj.instance_variable_set(:@trie, trie)
        obj.instance_variable_set(:@default, block)
        obj.freeze
      end
    end

    # @param pairs [::Enumerable] initial content of hash. An empty hash is returned if not provided.
    # @yield [key] Optional _default block_ to be stored and used to calculate the default value of a missing key. It will not be yielded during this method. It will not be preserved when marshalling.
    # @yieldparam key Key that was not present in the hash.
    def initialize(pairs = nil, &block)
      @trie    = pairs ? Trie[pairs] : EmptyTrie
      @default = block
      freeze
    end

    # Return the default block if there is one. Otherwise, return `nil`.
    #
    # @return [Proc]
    def default_proc
      @default
    end

    # Return the number of key/value pairs in this `Hash`.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].size  # => 3
    #
    # @return [Integer]
    def size
      @trie.size
    end
    alias length size

    # Return `true` if this `Hash` contains no key/value pairs.
    #
    # @return [Boolean]
    def empty?
      @trie.empty?
    end

    # Return `true` if the given key object is present in this `Hash`. More precisely,
    # return `true` if a key with the same `#hash` code, and which is also `#eql?`
    # to the given key object is present.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].key?("B")  # => true
    #
    # @param key [Object] The key to check for
    # @return [Boolean]
    def key?(key)
      @trie.key?(key)
    end
    alias has_key? key?
    alias include? key?
    alias member?  key?

    # Return `true` if this `Hash` has one or more keys which map to the provided value.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].value?(2)  # => true
    #
    # @param value [Object] The value to check for
    # @return [Boolean]
    def value?(value)
      each { |k,v| return true if value == v }
      false
    end
    alias has_value? value?

    # Retrieve the value corresponding to the provided key object. If not found, and
    # this `Hash` has a default block, the default block is called to provide the
    # value. Otherwise, return `nil`.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h["B"]             # => 2
    #   h.get("B")         # => 2
    #   h.get("Elephant")  # => nil
    #
    #   # Immutable Hash with a default proc:
    #   h = Immutable::Hash.new("A" => 1, "B" => 2, "C" => 3) { |key| key.size }
    #   h.get("B")         # => 2
    #   h.get("Elephant")  # => 8
    #
    # @param key [Object] The key to look up
    # @return [Object]
    def get(key)
      entry = @trie.get(key)
      if entry
        entry[1]
      elsif @default
        @default.call(key)
      end
    end
    alias [] get

    # Retrieve the value corresponding to the given key object, or use the provided
    # default value or block, or otherwise raise a `KeyError`.
    #
    # @overload fetch(key)
    #   Retrieve the value corresponding to the given key, or raise a `KeyError`
    #   if it is not found.
    #   @param key [Object] The key to look up
    # @overload fetch(key) { |key| ... }
    #   Retrieve the value corresponding to the given key, or call the optional
    #   code block (with the missing key) and get its return value.
    #   @yield [key] The key which was not found
    #   @yieldreturn [Object] Object to return since the key was not found
    #   @param key [Object] The key to look up
    # @overload fetch(key, default)
    #   Retrieve the value corresponding to the given key, or else return
    #   the provided `default` value.
    #   @param key [Object] The key to look up
    #   @param default [Object] Object to return if the key is not found
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.fetch("B")         # => 2
    #   h.fetch("Elephant")  # => KeyError: key not found: "Elephant"
    #
    #   # with a default value:
    #   h.fetch("B", 99)         # => 2
    #   h.fetch("Elephant", 99)  # => 99
    #
    #   # with a block:
    #   h.fetch("B") { |key| key.size }         # => 2
    #   h.fetch("Elephant") { |key| key.size }  # => 8
    #
    # @return [Object]
    def fetch(key, default = Undefined)
      entry = @trie.get(key)
      if entry
        entry[1]
      elsif block_given?
        yield(key)
      elsif default != Undefined
        default
      else
        raise KeyError, "key not found: #{key.inspect}"
      end
    end

    # Return a new `Hash` with the existing key/value associations, plus an association
    # between the provided key and value. If an equivalent key is already present, its
    # associated value will be replaced with the provided one.
    #
    # If the `value` argument is missing, but an optional code block is provided,
    # it will be passed the existing value (or `nil` if there is none) and what it
    # returns will replace the existing value. This is useful for "transforming"
    # the value associated with a certain key.
    #
    # Avoid mutating objects which are used as keys. `String`s are an exception:
    # unfrozen `String`s which are used as keys are internally duplicated and
    # frozen. This matches RubyHash's behaviour.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2]
    #   h.put("C", 3)
    #   # => Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.put("B") { |value| value * 10 }
    #   # => Immutable::Hash["A" => 1, "B" => 20]
    #
    # @param key [Object] The key to store
    # @param value [Object] The value to associate it with
    # @yield [value] The previously stored value, or `nil` if none.
    # @yieldreturn [Object] The new value to store
    # @return [Hash]
    def put(key, value = yield(get(key)))
      new_trie = @trie.put(key, value)
      if new_trie.equal?(@trie)
        self
      else
        self.class.alloc(new_trie, @default)
      end
    end

    # @private
    # @raise NoMethodError
    def []=(*)
      raise NoMethodError, "Immutable::Hash doesn't support `[]='; use `put' instead"
    end

    # Return a new `Hash` with a deeply nested value modified to the result of
    # the given code block.  When traversing the nested `Hash`es and `Vector`s,
    # non-existing keys are created with empty `Hash` values.
    #
    # The code block receives the existing value of the deeply nested key (or
    # `nil` if it doesn't exist). This is useful for "transforming" the value
    # associated with a certain key.
    #
    # Note that the original `Hash` and sub-`Hash`es and sub-`Vector`s are left
    # unmodified; new data structure copies are created along the path wherever
    # needed.
    #
    # @example
    #   hash = Immutable::Hash["a" => Immutable::Hash["b" => Immutable::Hash["c" => 42]]]
    #   hash.update_in("a", "b", "c") { |value| value + 5 }
    #   # => Immutable::Hash["a" => Immutable::Hash["b" => Immutable::Hash["c" => 47]]]
    #
    # @param key_path [::Array<Object>] List of keys which form the path to the key to be modified
    # @yield [value] The previously stored value
    # @yieldreturn [Object] The new value to store
    # @return [Hash]
    def update_in(*key_path, &block)
      if key_path.empty?
        raise ArgumentError, 'must have at least one key in path'
      end
      key = key_path[0]
      if key_path.size == 1
        new_value = block.call(get(key))
      else
        value = fetch(key, EmptyHash)
        new_value = value.update_in(*key_path[1..-1], &block)
      end
      put(key, new_value)
    end

    # An alias for {#put} to match RubyHash's API. Does not support {#put}'s
    # block form.
    #
    # @see #put
    # @param key [Object] The key to store
    # @param value [Object] The value to associate it with
    # @return [Hash]
    def store(key, value)
      put(key, value)
    end

    # Return a new `Hash` with `key` removed. If `key` is not present, return
    # `self`.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].delete("B")
    #   # => Immutable::Hash["A" => 1, "C" => 3]
    #
    # @param key [Object] The key to remove
    # @return [Hash]
    def delete(key)
      derive_new_hash(@trie.delete(key))
    end

    # Call the block once for each key/value pair in this `Hash`, passing the key/value
    # pair as parameters. No specific iteration order is guaranteed, though the order will
    # be stable for any particular `Hash`.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].each { |k, v| puts "k=#{k} v=#{v}" }
    #
    #   k=A v=1
    #   k=C v=3
    #   k=B v=2
    #   # => Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #
    # @yield [key, value] Once for each key/value pair.
    # @return [self]
    def each(&block)
      return to_enum if not block_given?
      @trie.each(&block)
      self
    end
    alias each_pair each

    # Call the block once for each key/value pair in this `Hash`, passing the key/value
    # pair as parameters. Iteration order will be the opposite of {#each}.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].reverse_each { |k, v| puts "k=#{k} v=#{v}" }
    #
    #   k=B v=2
    #   k=C v=3
    #   k=A v=1
    #   # => Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #
    # @yield [key, value] Once for each key/value pair.
    # @return [self]
    def reverse_each(&block)
      return enum_for(:reverse_each) if not block_given?
      @trie.reverse_each(&block)
      self
    end

    # Call the block once for each key/value pair in this `Hash`, passing the key as a
    # parameter. Ordering guarantees are the same as {#each}.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].each_key { |k| puts "k=#{k}" }
    #
    #   k=A
    #   k=C
    #   k=B
    #   # => Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #
    # @yield [key] Once for each key/value pair.
    # @return [self]
    def each_key
      return enum_for(:each_key) if not block_given?
      @trie.each { |k,v| yield k }
      self
    end

    # Call the block once for each key/value pair in this `Hash`, passing the value as a
    # parameter. Ordering guarantees are the same as {#each}.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].each_value { |v| puts "v=#{v}" }
    #
    #   v=1
    #   v=3
    #   v=2
    #   # => Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #
    # @yield [value] Once for each key/value pair.
    # @return [self]
    def each_value
      return enum_for(:each_value) if not block_given?
      @trie.each { |k,v| yield v }
      self
    end

    # Call the block once for each key/value pair in this `Hash`, passing the key/value
    # pair as parameters. The block should return a `[key, value]` array each time.
    # All the returned `[key, value]` arrays will be gathered into a new `Hash`.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.map { |k, v| ["new-#{k}", v * v] }
    #   # => Hash["new-C" => 9, "new-B" => 4, "new-A" => 1]
    #
    # @yield [key, value] Once for each key/value pair.
    # @return [Hash]
    def map
      return enum_for(:map) unless block_given?
      return self if empty?
      self.class.new(super, &@default)
    end
    alias collect map

    # Return a new `Hash` with all the key/value pairs for which the block returns true.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.select { |k, v| v >= 2 }
    #   # => Immutable::Hash["B" => 2, "C" => 3]
    #
    # @yield [key, value] Once for each key/value pair.
    # @yieldreturn Truthy if this pair should be present in the new `Hash`.
    # @return [Hash]
    def select(&block)
      return enum_for(:select) unless block_given?
      derive_new_hash(@trie.select(&block))
    end
    alias find_all select
    alias keep_if  select

    # Yield `[key, value]` pairs until one is found for which the block returns true.
    # Return that `[key, value]` pair. If the block never returns true, return `nil`.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.find { |k, v| v.even? }
    #   # => ["B", 2]
    #
    # @return [Array]
    # @yield [key, value] At most once for each key/value pair, until the block returns `true`.
    # @yieldreturn Truthy to halt iteration and return the yielded key/value pair.
    def find
      return enum_for(:find) unless block_given?
      each { |entry| return entry if yield entry }
      nil
    end
    alias detect find

    # Return a new `Hash` containing all the key/value pairs from this `Hash` and
    # `other`. If no block is provided, the value for entries with colliding keys
    # will be that from `other`. Otherwise, the value for each duplicate key is
    # determined by calling the block.
    #
    # `other` can be an `Immutable::Hash`, a built-in Ruby `Hash`, or any `Enumerable`
    # object which yields `[key, value]` pairs.
    #
    # @example
    #   h1 = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h2 = Immutable::Hash["C" => 70, "D" => 80]
    #   h1.merge(h2)
    #   # => Immutable::Hash["C" => 70, "A" => 1, "D" => 80, "B" => 2]
    #   h1.merge(h2) { |key, v1, v2| v1 + v2 }
    #   # => Immutable::Hash["C" => 73, "A" => 1, "D" => 80, "B" => 2]
    #
    # @param other [::Enumerable] The collection to merge with
    # @yieldparam key [Object] The key which was present in both collections
    # @yieldparam my_value [Object] The associated value from this `Hash`
    # @yieldparam other_value [Object] The associated value from the other collection
    # @yieldreturn [Object] The value to associate this key with in the new `Hash`
    # @return [Hash]
    def merge(other)
      trie = if block_given?
        other.reduce(@trie) do |trie, (key, value)|
          if (entry = trie.get(key))
            trie.put(key, yield(key, entry[1], value))
          else
            trie.put(key, value)
          end
        end
      else
        @trie.bulk_put(other)
      end

      derive_new_hash(trie)
    end

    # Retrieve the value corresponding to the given key object, or use the provided
    # default value or block, or otherwise raise a `KeyError`.
    #
    # @overload fetch(key)
    #   Retrieve the value corresponding to the given key, or raise a `KeyError`
    #   if it is not found.
    #   @param key [Object] The key to look up
    # @overload fetch(key) { |key| ... }

    # Return a sorted {Vector} which contains all the `[key, value]` pairs in
    # this `Hash` as two-element `Array`s.
    #
    # @overload sort
    #   Uses `#<=>` to determine sorted order.
    # @overload sort { |(k1, v1), (k2, v2)| ... }
    #   Uses the block as a comparator to determine sorted order.
    #
    #   @example
    #     h = Immutable::Hash["Dog" => 1, "Elephant" => 2, "Lion" => 3]
    #     h.sort { |(k1, v1), (k2, v2)| k1.size  <=> k2.size }
    #     # => Immutable::Vector[["Dog", 1], ["Lion", 3], ["Elephant", 2]]
    #   @yield [(k1, v1), (k2, v2)] Any number of times with different pairs of key/value associations.
    #   @yieldreturn [Integer] Negative if the first pair should be sorted
    #                          lower, positive if the latter pair, or 0 if equal.
    #
    # @see ::Enumerable#sort
    #
    # @return [Vector]
    def sort
      Vector.new(super)
    end

    # Return a {Vector} which contains all the `[key, value]` pairs in this `Hash`
    # as two-element Arrays. The order which the pairs will appear in is determined by
    # passing each pair to the code block to obtain a sort key object, and comparing
    # the sort keys using `#<=>`.
    #
    # @see ::Enumerable#sort_by
    #
    # @example
    #   h = Immutable::Hash["Dog" => 1, "Elephant" => 2, "Lion" => 3]
    #   h.sort_by { |key, value| key.size }
    #   # => Immutable::Vector[["Dog", 1], ["Lion", 3], ["Elephant", 2]]
    #
    # @yield [key, value] Once for each key/value pair.
    # @yieldreturn a sort key object for the yielded pair.
    # @return [Vector]
    def sort_by
      Vector.new(super)
    end

    # Return a new `Hash` with the associations for all of the given `keys` removed.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.except("A", "C")  # => Immutable::Hash["B" => 2]
    #
    # @param keys [Array] The keys to remove
    # @return [Hash]
    def except(*keys)
      keys.reduce(self) { |hash, key| hash.delete(key) }
    end

    # Return a new `Hash` with only the associations for the `wanted` keys retained.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.slice("B", "C")  # => Immutable::Hash["B" => 2, "C" => 3]
    #
    # @param wanted [::Enumerable] The keys to retain
    # @return [Hash]
    def slice(*wanted)
      trie = Trie.new(0)
      wanted.each { |key| trie.put!(key, get(key)) if key?(key) }
      self.class.alloc(trie, @default)
    end

    # Return a {Vector} of the values which correspond to the `wanted` keys.
    # If any of the `wanted` keys are not present in this `Hash`, `nil` will be
    # placed instead, or the result of the default proc (if one is defined),
    # similar to the behavior of {#get}.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.values_at("B", "A", "D")  # => Immutable::Vector[2, 1, nil]
    #
    # @param wanted [Array] The keys to retrieve
    # @return [Vector]
    def values_at(*wanted)
      Vector.new(wanted.map { |key| get(key) }.freeze)
    end

    # Return a {Vector} of the values which correspond to the `wanted` keys.
    # If any of the `wanted` keys are not present in this `Hash`, raise `KeyError`
    # exception.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.fetch_values("C", "A")  # => Immutable::Vector[3, 1]
    #   h.fetch_values("C", "Z")  # => KeyError: key not found: "Z"
    #
    # @param wanted [Array] The keys to retrieve
    # @return [Vector]
    def fetch_values(*wanted)
      array = wanted.map { |key| fetch(key) }
      Vector.new(array.freeze)
    end

    # Return the value of successively indexing into a nested collection.
    # If any of the keys is not present, return `nil`.
    #
    # @example
    #   h = Immutable::Hash[a: 9, b: Immutable::Hash[c: 'a', d: 4], e: nil]
    #   h.dig(:b, :c) # => "a"
    #   h.dig(:b, :f) # => nil
    #
    # @return [Object]
    def dig(key, *rest)
      value = self[key]
      if rest.empty? || value.nil?
        value
      else
        value.dig(*rest)
      end
    end

    # Return a new {Set} containing the keys from this `Hash`.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3, "D" => 2].keys
    #   # => Immutable::Set["D", "C", "B", "A"]
    #
    # @return [Set]
    def keys
      Set.alloc(@trie)
    end

    # Return a new {Vector} populated with the values from this `Hash`.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3, "D" => 2].values
    #   # => Immutable::Vector[2, 3, 2, 1]
    #
    # @return [Vector]
    def values
      Vector.new(each_value.to_a.freeze)
    end

    # Return a new `Hash` created by using keys as values and values as keys.
    # If there are multiple values which are equivalent (as determined by `#hash` and
    # `#eql?`), only one out of each group of equivalent values will be
    # retained. Which one specifically is undefined.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3, "D" => 2].invert
    #   # => Immutable::Hash[1 => "A", 3 => "C", 2 => "B"]
    #
    # @return [Hash]
    def invert
      pairs = []
      each { |k,v| pairs << [v, k] }
      self.class.new(pairs, &@default)
    end

    # Return a new {Vector} which is a one-dimensional flattening of this `Hash`.
    # If `level` is 1, all the `[key, value]` pairs in the hash will be concatenated
    # into one {Vector}. If `level` is greater than 1, keys or values which are
    # themselves `Array`s or {Vector}s will be recursively flattened into the output
    # {Vector}. The depth to which that flattening will be recursively applied is
    # determined by `level`.
    #
    # As a special case, if `level` is 0, each `[key, value]` pair will be a
    # separate element in the returned {Vector}.
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => [2, 3, 4]]
    #   h.flatten
    #   # => Immutable::Vector["A", 1, "B", [2, 3, 4]]
    #   h.flatten(2)
    #   # => Immutable::Vector["A", 1, "B", 2, 3, 4]
    #
    # @param level [Integer] The number of times to recursively flatten the `[key, value]` pairs in this `Hash`.
    # @return [Vector]
    def flatten(level = 1)
      return Vector.new(self) if level == 0
      array = []
      each { |k,v| array << k; array << v }
      array.flatten!(level-1) if level > 1
      Vector.new(array.freeze)
    end

    # Searches through the `Hash`, comparing `obj` with each key (using `#==`).
    # When a matching key is found, return the `[key, value]` pair as an array.
    # Return `nil` if no match is found.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].assoc("B")  # => ["B", 2]
    #
    # @param obj [Object] The key to search for (using #==)
    # @return [Array]
    def assoc(obj)
      each { |entry| return entry if obj == entry[0] }
      nil
    end

    # Searches through the `Hash`, comparing `obj` with each value (using `#==`).
    # When a matching value is found, return the `[key, value]` pair as an array.
    # Return `nil` if no match is found.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].rassoc(2)  # => ["B", 2]
    #
    # @param obj [Object] The value to search for (using #==)
    # @return [Array]
    def rassoc(obj)
      each { |entry| return entry if obj == entry[1] }
      nil
    end

    # Searches through the `Hash`, comparing `value` with each value (using `#==`).
    # When a matching value is found, return its associated key object.
    # Return `nil` if no match is found.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].key(2)  # => "B"
    #
    # @param value [Object] The value to search for (using #==)
    # @return [Object]
    def key(value)
      each { |entry| return entry[0] if value == entry[1] }
      nil
    end

    # Return a randomly chosen `[key, value]` pair from this `Hash`. If the hash is empty,
    # return `nil`.
    #
    # @example
    #   Immutable::Hash["A" => 1, "B" => 2, "C" => 3].sample
    #   # => ["C", 3]
    #
    # @return [Array]
    def sample
      @trie.at(rand(size))
    end

    # Return an empty `Hash` instance, of the same class as this one. Useful if you
    # have multiple subclasses of `Hash` and want to treat them polymorphically.
    # Maintains the default block, if there is one.
    #
    # @return [Hash]
    def clear
      if @default
        self.class.alloc(EmptyTrie, @default)
      else
        self.class.empty
      end
    end

    # Return true if `other` has the same type and contents as this `Hash`.
    #
    # @param other [Object] The collection to compare with
    # @return [Boolean]
    def eql?(other)
      return true if other.equal?(self)
      instance_of?(other.class) && @trie.eql?(other.instance_variable_get(:@trie))
    end

    # Return true if `other` has the same contents as this `Hash`. Will convert
    # `other` to a Ruby `Hash` using `#to_hash` if necessary.
    #
    # @param other [Object] The object to compare with
    # @return [Boolean]
    def ==(other)
      eql?(other) || (other.respond_to?(:to_hash) && to_hash == other.to_hash)
    end

    # Return true if this `Hash` is a proper superset of `other`, which means
    # all `other`'s keys are contained in this `Hash` with identical
    # values, and the two hashes are not identical.
    #
    # @param other [Immutable::Hash] The object to compare with
    # @return [Boolean]
    def >(other)
      self != other && self >= other
    end

    # Return true if this `Hash` is a superset of `other`, which means all
    # `other`'s keys are contained in this `Hash` with identical values.
    #
    # @param other [Immutable::Hash] The object to compare with
    # @return [Boolean]
    def >=(other)
      other.each do |key, value|
        if self[key] != value
          return false
        end
      end
      true
    end

    # Return true if this `Hash` is a proper subset of `other`, which means all
    # its keys are contained in `other` with the identical values, and the two
    # hashes are not identical.
    #
    # @param other [Immutable::Hash] The object to compare with
    # @return [Boolean]
    def <(other)
      other > self
    end

    # Return true if this `Hash` is a subset of `other`, which means all its
    # keys are contained in `other` with the identical values, and the two
    # hashes are not identical.
    #
    # @param other [Immutable::Hash] The object to compare with
    # @return [Boolean]
    def <=(other)
      other >= self
    end

    # See `Object#hash`.
    # @return [Integer]
    def hash
      keys.to_a.sort.reduce(0) do |hash, key|
        (hash << 32) - hash + key.hash + get(key).hash
      end
    end

    # Return the contents of this `Hash` as a programmer-readable `String`. If all the
    # keys and values are serializable as Ruby literal strings, the returned string can
    # be passed to `eval` to reconstitute an equivalent `Hash`. The default
    # block (if there is one) will be lost when doing this, however.
    #
    # @return [String]
    def inspect
      result = "#{self.class}["
      i = 0
      each do |key, val|
        result << ', ' if i > 0
        result << key.inspect << ' => ' << val.inspect
        i += 1
      end
      result << ']'
    end

    # Return `self`. Since this is an immutable object duplicates are
    # equivalent.
    # @return [Hash]
    def dup
      self
    end
    alias clone dup

    # Allows this `Hash` to be printed at the `pry` console, or using `pp` (from the
    # Ruby standard library), in a way which takes the amount of horizontal space on
    # the screen into account, and which indents nested structures to make them easier
    # to read.
    #
    # @private
    def pretty_print(pp)
      pp.group(1, "#{self.class}[", ']') do
        pp.breakable ''
        pp.seplist(self, nil) do |key, val|
          pp.group do
            key.pretty_print(pp)
            pp.text ' => '
            pp.group(1) do
              pp.breakable ''
              val.pretty_print(pp)
            end
          end
        end
      end
    end

    # Convert this `Immutable::Hash` to an instance of Ruby's built-in `Hash`.
    #
    # @return [::Hash]
    def to_hash
      output = {}
      each do |key, value|
        output[key] = value
      end
      output
    end
    alias to_h to_hash

    # Return a `Proc` which accepts a key as an argument and returns the value.
    # The `Proc` behaves like {#get} (when the key is missing, it returns nil or
    # the result of the default proc).
    #
    # @example
    #   h = Immutable::Hash["A" => 1, "B" => 2, "C" => 3]
    #   h.to_proc.call("B")
    #   # => 2
    #   ["A", "C", "X"].map(&h)   # The & is short for .to_proc in Ruby
    #   # => [1, 3, nil]
    #
    # @return [Proc]
    def to_proc
      lambda { |key| get(key) }
    end

    # @return [::Hash]
    # @private
    def marshal_dump
      to_hash
    end

    # @private
    def marshal_load(dictionary)
      @trie = Trie[dictionary]
    end

    private

    # Return a new `Hash` which is derived from this one, using a modified {Trie}.
    # The new `Hash` will retain the existing default block, if there is one.
    #
    def derive_new_hash(trie)
      if trie.equal?(@trie)
        self
      elsif trie.empty?
        if @default
          self.class.alloc(EmptyTrie, @default)
        else
          self.class.empty
        end
      else
        self.class.alloc(trie, @default)
      end
    end
  end

  # The canonical empty `Hash`. Returned by `Hash[]` when
  # invoked with no arguments; also returned by `Hash.empty`. Prefer using this
  # one rather than creating many empty hashes using `Hash.new`.
  #
  # @private
  EmptyHash = Immutable::Hash.empty


  # A `Vector` is an ordered, integer-indexed collection of objects. Like
  # Ruby's `Array`, `Vector` indexing starts at zero and negative indexes count
  # back from the end.
  #
  # `Vector` has a similar interface to `Array`. The main difference is methods
  # that would destructively update an `Array` (such as {#insert} or
  # {#delete_at}) instead return new `Vectors` and leave the existing one
  # unchanged.
  #
  # ### Creating New Vectors
  #
  #     Immutable::Vector.new([:first, :second, :third])
  #     Immutable::Vector[1, 2, 3, 4, 5]
  #
  # ### Retrieving Items from Vectors
  #
  #     vector = Immutable::Vector[1, 2, 3, 4, 5]
  #
  #     vector[0]      # => 1
  #     vector[-1]     # => 5
  #     vector[0,3]    # => Immutable::Vector[1, 2, 3]
  #     vector[1..-1]  # => Immutable::Vector[2, 3, 4, 5]
  #     vector.first   # => 1
  #     vector.last    # => 5
  #
  # ### Creating Modified Vectors
  #
  #     vector.add(6)            # => Immutable::Vector[1, 2, 3, 4, 5, 6]
  #     vector.insert(1, :a, :b) # => Immutable::Vector[1, :a, :b, 2, 3, 4, 5]
  #     vector.delete_at(2)      # => Immutable::Vector[1, 2, 4, 5]
  #     vector + [6, 7]          # => Immutable::Vector[1, 2, 3, 4, 5, 6, 7]
  #
  class Vector
    include Immutable::Enumerable

    # @private
    BLOCK_SIZE = 32
    # @private
    INDEX_MASK = BLOCK_SIZE - 1
    # @private
    BITS_PER_LEVEL = 5

    # Return the number of items in this `Vector`
    # @return [Integer]
    attr_reader :size
    alias length size

    class << self
      # Create a new `Vector` populated with the given items.
      # @return [Vector]
      def [](*items)
        new(items.freeze)
      end

      # Return an empty `Vector`. If used on a subclass, returns an empty instance
      # of that class.
      #
      # @return [Vector]
      def empty
        @empty ||= new
      end

      # "Raw" allocation of a new `Vector`. Used internally to create a new
      # instance quickly after building a modified trie.
      #
      # @return [Vector]
      # @private
      def alloc(root, size, levels)
        obj = allocate
        obj.instance_variable_set(:@root, root)
        obj.instance_variable_set(:@size, size)
        obj.instance_variable_set(:@levels, levels)
        obj.freeze
      end
    end

    def initialize(items=[].freeze)
      items = items.to_a
      if items.size <= 32
        items = items.dup.freeze if !items.frozen?
        @root, @size, @levels = items, items.size, 0
      else
        root, size, levels = items, items.size, 0
        while root.size > 32
          root = root.each_slice(32).to_a
          levels += 1
        end
        @root, @size, @levels = root.freeze, size, levels
      end
      freeze
    end

    # Return `true` if this `Vector` contains no items.
    #
    # @return [Boolean]
    def empty?
      @size == 0
    end

    # Return the first item in the `Vector`. If the vector is empty, return `nil`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].first  # => "A"
    #
    # @return [Object]
    def first
      get(0)
    end

    # Return the last item in the `Vector`. If the vector is empty, return `nil`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].last  # => "C"
    #
    # @return [Object]
    def last
      get(-1)
    end

    # Return a new `Vector` with `item` added after the last occupied position.
    #
    # @example
    #   Immutable::Vector[1, 2].add(99)  # => Immutable::Vector[1, 2, 99]
    #
    # @param item [Object] The object to insert at the end of the vector
    # @return [Vector]
    def add(item)
      update_root(@size, item)
    end
    alias << add
    alias push add

    # Return a new `Vector` with a new value at the given `index`. If `index`
    # is greater than the length of the vector, the returned vector will be
    # padded with `nil`s to the correct size.
    #
    # @overload set(index, item)
    #   Return a new `Vector` with the item at `index` replaced by `item`.
    #
    #   @param item [Object] The object to insert into that position
    #   @example
    #     Immutable::Vector[1, 2, 3, 4].set(2, 99)
    #     # => Immutable::Vector[1, 2, 99, 4]
    #     Immutable::Vector[1, 2, 3, 4].set(-1, 99)
    #     # => Immutable::Vector[1, 2, 3, 99]
    #     Immutable::Vector[].set(2, 99)
    #     # => Immutable::Vector[nil, nil, 99]
    #
    # @overload set(index)
    #   Return a new `Vector` with the item at `index` replaced by the return
    #   value of the block.
    #
    #   @yield (existing) Once with the existing value at the given `index`.
    #   @example
    #     Immutable::Vector[1, 2, 3, 4].set(2) { |v| v * 10 }
    #     # => Immutable::Vector[1, 2, 30, 4]
    #
    # @param index [Integer] The index to update. May be negative.
    # @return [Vector]
    def set(index, item = yield(get(index)))
      raise IndexError, "index #{index} outside of vector bounds" if index < -@size
      index += @size if index < 0
      if index > @size
        suffix = Array.new(index - @size, nil)
        suffix << item
        replace_suffix(@size, suffix)
      else
        update_root(index, item)
      end
    end

    # Return a new `Vector` with a deeply nested value modified to the result
    # of the given code block.  When traversing the nested `Vector`s and
    # `Hash`es, non-existing keys are created with empty `Hash` values.
    #
    # The code block receives the existing value of the deeply nested key (or
    # `nil` if it doesn't exist). This is useful for "transforming" the value
    # associated with a certain key.
    #
    # Note that the original `Vector` and sub-`Vector`s and sub-`Hash`es are
    # left unmodified; new data structure copies are created along the path
    # wherever needed.
    #
    # @example
    #   v = Immutable::Vector[123, 456, 789, Immutable::Hash["a" => Immutable::Vector[5, 6, 7]]]
    #   v.update_in(3, "a", 1) { |value| value + 9 }
    #   # => Immutable::Vector[123, 456, 789, Immutable::Hash["a" => Immutable::Vector[5, 15, 7]]]
    #
    # @param key_path [Object(s)] List of keys which form the path to the key to be modified
    # @yield [value] The previously stored value
    # @yieldreturn [Object] The new value to store
    # @return [Vector]
    def update_in(*key_path, &block)
      if key_path.empty?
        raise ArgumentError, 'must have at least one key in path'
      end
      key = key_path[0]
      if key_path.size == 1
        new_value = block.call(get(key))
      else
        value = fetch(key, Immutable::EmptyHash)
        new_value = value.update_in(*key_path[1..-1], &block)
      end
      set(key, new_value)
    end

    # Retrieve the item at `index`. If there is none (either the provided index
    # is too high or too low), return `nil`.
    #
    # @example
    #   v = Immutable::Vector["A", "B", "C", "D"]
    #   v.get(2)   # => "C"
    #   v.get(-1)  # => "D"
    #   v.get(4)   # => nil
    #
    # @param index [Integer] The index to retrieve
    # @return [Object]
    def get(index)
      return nil if @size == 0
      index += @size if index < 0
      return nil if index >= @size || index < 0
      leaf_node_for(@root, @levels * BITS_PER_LEVEL, index)[index & INDEX_MASK]
    end
    alias at get

    # Retrieve the value at `index` with optional default.
    #
    # @overload fetch(index)
    #   Retrieve the value at the given index, or raise an `IndexError` if not
    #   found.
    #
    #   @param index [Integer] The index to look up
    #   @raise [IndexError] if index does not exist
    #   @example
    #     v = Immutable::Vector["A", "B", "C", "D"]
    #     v.fetch(2)       # => "C"
    #     v.fetch(-1)      # => "D"
    #     v.fetch(4)       # => IndexError: index 4 outside of vector bounds
    #
    # @overload fetch(index) { |index| ... }
    #   Retrieve the value at the given index, or return the result of yielding
    #   the block if not found.
    #
    #   @yield Once if the index is not found.
    #   @yieldparam [Integer] index The index which does not exist
    #   @yieldreturn [Object] Default value to return
    #   @param index [Integer] The index to look up
    #   @example
    #     v = Immutable::Vector["A", "B", "C", "D"]
    #     v.fetch(2) { |i| i * i }   # => "C"
    #     v.fetch(4) { |i| i * i }   # => 16
    #
    # @overload fetch(index, default)
    #   Retrieve the value at the given index, or return the provided `default`
    #   value if not found.
    #
    #   @param index [Integer] The index to look up
    #   @param default [Object] Object to return if the key is not found
    #   @example
    #     v = Immutable::Vector["A", "B", "C", "D"]
    #     v.fetch(2, "Z")  # => "C"
    #     v.fetch(4, "Z")  # => "Z"
    #
    # @return [Object]
    def fetch(index, default = (missing_default = true))
      if index >= -@size && index < @size
        get(index)
      elsif block_given?
        yield(index)
      elsif !missing_default
        default
      else
        raise IndexError, "index #{index} outside of vector bounds"
      end
    end

    # Return the value of successively indexing into a nested collection.
    # If any of the keys is not present, return `nil`.
    #
    # @example
    #   v = Immutable::Vector[9, Immutable::Hash[c: 'a', d: 4]]
    #   v.dig(1, :c) # => "a"
    #   v.dig(1, :f) # => nil
    #
    # @return [Object]
    def dig(key, *rest)
      value = self[key]
      if rest.empty? || value.nil?
        value
      else
        value.dig(*rest)
      end
    end

    # Return specific objects from the `Vector`. All overloads return `nil` if
    # the starting index is out of range.
    #
    # @overload vector.slice(index)
    #   Returns a single object at the given `index`. If `index` is negative,
    #   count backwards from the end.
    #
    #   @param index [Integer] The index to retrieve. May be negative.
    #   @return [Object]
    #   @example
    #     v = Immutable::Vector["A", "B", "C", "D", "E", "F"]
    #     v[2]  # => "C"
    #     v[-1] # => "F"
    #     v[6]  # => nil
    #
    # @overload vector.slice(index, length)
    #   Return a subvector starting at `index` and continuing for `length`
    #   elements or until the end of the `Vector`, whichever occurs first.
    #
    #   @param start [Integer] The index to start retrieving items from. May be
    #                          negative.
    #   @param length [Integer] The number of items to retrieve.
    #   @return [Vector]
    #   @example
    #     v = Immutable::Vector["A", "B", "C", "D", "E", "F"]
    #     v[2, 3]  # => Immutable::Vector["C", "D", "E"]
    #     v[-2, 3] # => Immutable::Vector["E", "F"]
    #     v[20, 1] # => nil
    #
    # @overload vector.slice(index..end)
    #   Return a subvector starting at `index` and continuing to index
    #   `end` or the end of the `Vector`, whichever occurs first.
    #
    #   @param range [Range] The range of indices to retrieve.
    #   @return [Vector]
    #   @example
    #     v = Immutable::Vector["A", "B", "C", "D", "E", "F"]
    #     v[2..3]    # => Immutable::Vector["C", "D"]
    #     v[-2..100] # => Immutable::Vector["E", "F"]
    #     v[20..21]  # => nil
    def slice(arg, length = (missing_length = true))
      if missing_length
        if arg.is_a?(Range)
          from, to = arg.begin, arg.end
          from += @size if from < 0
          to   += @size if to < 0
          to   += 1     if !arg.exclude_end?
          length = to - from
          length = 0 if length < 0
          subsequence(from, length)
        else
          get(arg)
        end
      else
        arg += @size if arg < 0
        subsequence(arg, length)
      end
    end
    alias [] slice

    # Return a new `Vector` with the given values inserted before the element
    # at `index`. If `index` is greater than the current length, `nil` values
    # are added to pad the `Vector` to the required size.
    #
    # @example
    #   Immutable::Vector["A", "B", "C", "D"].insert(2, "X", "Y", "Z")
    #   # => Immutable::Vector["A", "B", "X", "Y", "Z", "C", "D"]
    #   Immutable::Vector[].insert(2, "X", "Y", "Z")
    #   # => Immutable::Vector[nil, nil, "X", "Y", "Z"]
    #
    # @param index [Integer] The index where the new items should go
    # @param items [Array] The items to add
    # @return [Vector]
    # @raise [IndexError] if index exceeds negative range.
    def insert(index, *items)
      raise IndexError if index < -@size
      index += @size if index < 0

      if index < @size
        suffix = flatten_suffix(@root, @levels * BITS_PER_LEVEL, index, [])
        suffix.unshift(*items)
      elsif index == @size
        suffix = items
      else
        suffix = Array.new(index - @size, nil).concat(items)
        index = @size
      end

      replace_suffix(index, suffix)
    end

    # Return a new `Vector` with the element at `index` removed. If the given `index`
    # does not exist, return `self`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C", "D"].delete_at(2)
    #   # => Immutable::Vector["A", "B", "D"]
    #
    # @param index [Integer] The index to remove
    # @return [Vector]
    def delete_at(index)
      return self if index >= @size || index < -@size
      index += @size if index < 0

      suffix = flatten_suffix(@root, @levels * BITS_PER_LEVEL, index, [])
      replace_suffix(index, suffix.tap(&:shift))
    end

    # Return a new `Vector` with the last element removed. Return `self` if
    # empty.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].pop  # => Immutable::Vector["A", "B"]
    #
    # @return [Vector]
    def pop
      return self if @size == 0
      replace_suffix(@size-1, [])
    end

    # Return a new `Vector` with `object` inserted before the first element,
    # moving the other elements upwards.
    #
    # @example
    #   Immutable::Vector["A", "B"].unshift("Z")
    #   # => Immutable::Vector["Z", "A", "B"]
    #
    # @param object [Object] The value to prepend
    # @return [Vector]
    def unshift(object)
      insert(0, object)
    end

    # Return a new `Vector` with the first element removed. If empty, return
    # `self`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].shift  # => Immutable::Vector["B", "C"]
    #
    # @return [Vector]
    def shift
      delete_at(0)
    end

    # Call the given block once for each item in the vector, passing each
    # item from first to last successively to the block. If no block is given,
    # an `Enumerator` is returned instead.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].each { |e| puts "Element: #{e}" }
    #
    #   Element: A
    #   Element: B
    #   Element: C
    #   # => Immutable::Vector["A", "B", "C"]
    #
    # @return [self, Enumerator]
    def each(&block)
      return to_enum unless block_given?
      traverse_depth_first(@root, @levels, &block)
      self
    end

    # Call the given block once for each item in the vector, from last to
    # first.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].reverse_each { |e| puts "Element: #{e}" }
    #
    #   Element: C
    #   Element: B
    #   Element: A
    #
    # @return [self]
    def reverse_each(&block)
      return enum_for(:reverse_each) unless block_given?
      reverse_traverse_depth_first(@root, @levels, &block)
      self
    end

    # Return a new `Vector` containing all elements for which the given block returns
    # true.
    #
    # @example
    #   Immutable::Vector["Bird", "Cow", "Elephant"].select { |e| e.size >= 4 }
    #   # => Immutable::Vector["Bird", "Elephant"]
    #
    # @return [Vector]
    # @yield [element] Once for each element.
    def select
      return enum_for(:select) unless block_given?
      reduce(self.class.empty) { |vector, item| yield(item) ? vector.add(item) : vector }
    end
    alias find_all select
    alias keep_if  select

    # Return a new `Vector` with all items which are equal to `obj` removed.
    # `#==` is used for checking equality.
    #
    # @example
    #   Immutable::Vector["C", "B", "A", "B"].delete("B")  # => Immutable::Vector["C", "A"]
    #
    # @param obj [Object] The object to remove (every occurrence)
    # @return [Vector]
    def delete(obj)
      select { |item| item != obj }
    end

    # Invoke the given block once for each item in the vector, and return a new
    # `Vector` containing the values returned by the block. If no block is
    # provided, return an enumerator.
    #
    # @example
    #   Immutable::Vector[3, 2, 1].map { |e| e * e }  # => Immutable::Vector[9, 4, 1]
    #
    # @return [Vector, Enumerator]
    def map
      return enum_for(:map) if not block_given?
      return self if empty?
      self.class.new(super)
    end
    alias collect map

    # Return a new `Vector` with the concatenated results of running the block once
    # for every element in this `Vector`.
    #
    # @example
    #   Immutable::Vector[1, 2, 3].flat_map { |x| [x, -x] }
    #   # => Immutable::Vector[1, -1, 2, -2, 3, -3]
    #
    # @return [Vector]
    def flat_map
      return enum_for(:flat_map) if not block_given?
      return self if empty?
      self.class.new(super)
    end

    # Return a new `Vector` with the same elements as this one, but randomly permuted.
    #
    # @example
    #   Immutable::Vector[1, 2, 3, 4].shuffle  # => Immutable::Vector[4, 1, 3, 2]
    #
    # @return [Vector]
    def shuffle
      self.class.new(((array = to_a).frozen? ? array.shuffle : array.shuffle!).freeze)
    end

    # Return a new `Vector` with no duplicate elements, as determined by `#hash` and
    # `#eql?`. For each group of equivalent elements, only the first will be retained.
    #
    # @example
    #   Immutable::Vector["A", "B", "C", "B"].uniq      # => Immutable::Vector["A", "B", "C"]
    #   Immutable::Vector["a", "A", "b"].uniq(&:upcase) # => Immutable::Vector["a", "b"]
    #
    # @return [Vector]
    def uniq(&block)
      array = to_a
      if array.frozen?
        self.class.new(array.uniq(&block).freeze)
      elsif array.uniq!(&block) # returns nil if no changes were made
        self.class.new(array.freeze)
      else
        self
      end
    end

    # Return a new `Vector` with the same elements as this one, but in reverse order.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"].reverse  # => Immutable::Vector["C", "B", "A"]
    #
    # @return [Vector]
    def reverse
      self.class.new(((array = to_a).frozen? ? array.reverse : array.reverse!).freeze)
    end

    # Return a new `Vector` with the same elements, but rotated so that the one at
    # index `count` is the first element of the new vector. If `count` is positive,
    # the elements will be shifted left, and those shifted past the lowest position
    # will be moved to the end. If `count` is negative, the elements will be shifted
    # right, and those shifted past the last position will be moved to the beginning.
    #
    # @example
    #   v = Immutable::Vector["A", "B", "C", "D", "E", "F"]
    #   v.rotate(2)   # => Immutable::Vector["C", "D", "E", "F", "A", "B"]
    #   v.rotate(-1)  # => Immutable::Vector["F", "A", "B", "C", "D", "E"]
    #
    # @param count [Integer] The number of positions to shift items by
    # @return [Vector]
    def rotate(count = 1)
      return self if (count % @size) == 0
      self.class.new(((array = to_a).frozen? ? array.rotate(count) : array.rotate!(count)).freeze)
    end

    # Return a new `Vector` with all nested vectors and arrays recursively "flattened
    # out". That is, their elements inserted into the new `Vector` in the place where
    # the nested array/vector originally was. If an optional `level` argument is
    # provided, the flattening will only be done recursively that number of times.
    # A `level` of 0 means not to flatten at all, 1 means to only flatten nested
    # arrays/vectors which are directly contained within this `Vector`.
    #
    # @example
    #   v = Immutable::Vector["A", Immutable::Vector["B", "C", Immutable::Vector["D"]]]
    #   v.flatten(1)
    #   # => Immutable::Vector["A", "B", "C", Immutable::Vector["D"]]
    #   v.flatten
    #   # => Immutable::Vector["A", "B", "C", "D"]
    #
    # @param level [Integer] The depth to which flattening should be applied
    # @return [Vector]
    def flatten(level = -1)
      return self if level == 0
      array = to_a
      if array.frozen?
        self.class.new(array.flatten(level).freeze)
      elsif array.flatten!(level) # returns nil if no changes were made
        self.class.new(array.freeze)
      else
        self
      end
    end

    # Return a new `Vector` built by concatenating this one with `other`. `other`
    # can be any object which is convertible to an `Array` using `#to_a`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C"] + ["D", "E"]
    #   # => Immutable::Vector["A", "B", "C", "D", "E"]
    #
    # @param other [Enumerable] The collection to concatenate onto this vector
    # @return [Vector]
    def +(other)
      other = other.to_a
      other = other.dup if other.frozen?
      replace_suffix(@size, other)
    end
    alias concat +

    # Combine two vectors by "zipping" them together. `others` should be arrays
    # and/or vectors. The corresponding elements from this `Vector` and each of
    # `others` (that is, the elements with the same indices) will be gathered
    # into arrays.
    #
    # If `others` contains fewer elements than this vector, `nil` will be used
    # for padding.
    #
    # @overload zip(*others)
    #   Return a new vector containing the new arrays.
    #
    #   @return [Vector]
    #
    # @overload zip(*others)
    #   @yield [pair] once for each array
    #   @return [nil]
    #
    # @example
    #   v1 = Immutable::Vector["A", "B", "C"]
    #   v2 = Immutable::Vector[1, 2]
    #   v1.zip(v2)
    #   # => Immutable::Vector[["A", 1], ["B", 2], ["C", nil]]
    #
    # @param others [Array] The arrays/vectors to zip together with this one
    # @return [Vector]
    def zip(*others)
      if block_given?
        super
      else
        self.class.new(super)
      end
    end

    # Return a new `Vector` with the same items, but sorted.
    #
    # @overload sort
    #   Compare elements with their natural sort key (`#<=>`).
    #
    #   @example
    #     Immutable::Vector["Elephant", "Dog", "Lion"].sort
    #     # => Immutable::Vector["Dog", "Elephant", "Lion"]
    #
    # @overload sort
    #   Uses the block as a comparator to determine sorted order.
    #
    #   @yield [a, b] Any number of times with different pairs of elements.
    #   @yieldreturn [Integer] Negative if the first element should be sorted
    #                          lower, positive if the latter element, or 0 if
    #                          equal.
    #   @example
    #     Immutable::Vector["Elephant", "Dog", "Lion"].sort { |a,b| a.size <=> b.size }
    #     # => Immutable::Vector["Dog", "Lion", "Elephant"]
    #
    # @return [Vector]
    def sort
      self.class.new(super)
    end

    # Return a new `Vector` with the same items, but sorted. The sort order is
    # determined by mapping the items through the given block to obtain sort
    # keys, and then sorting the keys according to their natural sort order
    # (`#<=>`).
    #
    # @yield [element] Once for each element.
    # @yieldreturn a sort key object for the yielded element.
    # @example
    #   Immutable::Vector["Elephant", "Dog", "Lion"].sort_by { |e| e.size }
    #   # => Immutable::Vector["Dog", "Lion", "Elephant"]
    #
    # @return [Vector]
    def sort_by
      self.class.new(super)
    end

    # Drop the first `n` elements and return the rest in a new `Vector`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C", "D", "E", "F"].drop(2)
    #   # => Immutable::Vector["C", "D", "E", "F"]
    #
    # @param n [Integer] The number of elements to remove
    # @return [Vector]
    # @raise ArgumentError if `n` is negative.
    def drop(n)
      return self if n == 0
      return self.class.empty if n >= @size
      raise ArgumentError, 'attempt to drop negative size' if n < 0
      self.class.new(flatten_suffix(@root, @levels * BITS_PER_LEVEL, n, []))
    end

    # Return only the first `n` elements in a new `Vector`.
    #
    # @example
    #   Immutable::Vector["A", "B", "C", "D", "E", "F"].take(4)
    #   # => Immutable::Vector["A", "B", "C", "D"]
    #
    # @param n [Integer] The number of elements to retain
    # @return [Vector]
    def take(n)
      return self if n >= @size
      self.class.new(super)
    end

    # Drop elements up to, but not including, the first element for which the
    # block returns `nil` or `false`. Gather the remaining elements into a new
    # `Vector`. If no block is given, an `Enumerator` is returned instead.
    #
    # @example
    #   Immutable::Vector[1, 3, 5, 7, 6, 4, 2].drop_while { |e| e < 5 }
    #   # => Immutable::Vector[5, 7, 6, 4, 2]
    #
    # @return [Vector, Enumerator]
    def drop_while
      return enum_for(:drop_while) if not block_given?
      self.class.new(super)
    end

    # Gather elements up to, but not including, the first element for which the
    # block returns `nil` or `false`, and return them in a new `Vector`. If no block
    # is given, an `Enumerator` is returned instead.
    #
    # @example
    #   Immutable::Vector[1, 3, 5, 7, 6, 4, 2].take_while { |e| e < 5 }
    #   # => Immutable::Vector[1, 3]
    #
    # @return [Vector, Enumerator]
    def take_while
      return enum_for(:take_while) if not block_given?
      self.class.new(super)
    end

    # Repetition. Return a new `Vector` built by concatenating `times` copies
    # of this one together.
    #
    # @example
    #   Immutable::Vector["A", "B"] * 3
    #   # => Immutable::Vector["A", "B", "A", "B", "A", "B"]
    #
    # @param times [Integer] The number of times to repeat the elements in this vector
    # @return [Vector]
    def *(times)
      return self.class.empty if times == 0
      return self if times == 1
      result = (to_a * times)
      result.is_a?(Array) ? self.class.new(result) : result
    end

    # Replace a range of indexes with the given object.
    #
    # @overload fill(object)
    #   Return a new `Vector` of the same size, with every index set to
    #   `object`.
    #
    #   @param [Object] object Fill value.
    #   @example
    #     Immutable::Vector["A", "B", "C", "D", "E", "F"].fill("Z")
    #     # => Immutable::Vector["Z", "Z", "Z", "Z", "Z", "Z"]
    #
    # @overload fill(object, index)
    #   Return a new `Vector` with all indexes from `index` to the end of the
    #   vector set to `object`.
    #
    #   @param [Object] object Fill value.
    #   @param [Integer] index Starting index. May be negative.
    #   @example
    #     Immutable::Vector["A", "B", "C", "D", "E", "F"].fill("Z", 3)
    #     # => Immutable::Vector["A", "B", "C", "Z", "Z", "Z"]
    #
    # @overload fill(object, index, length)
    #   Return a new `Vector` with `length` indexes, beginning from `index`,
    #   set to `object`. Expands the `Vector` if `length` would extend beyond
    #   the current length.
    #
    #   @param [Object] object Fill value.
    #   @param [Integer] index Starting index. May be negative.
    #   @param [Integer] length
    #   @example
    #     Immutable::Vector["A", "B", "C", "D", "E", "F"].fill("Z", 3, 2)
    #     # => Immutable::Vector["A", "B", "C", "Z", "Z", "F"]
    #     Immutable::Vector["A", "B"].fill("Z", 1, 5)
    #     # => Immutable::Vector["A", "Z", "Z", "Z", "Z", "Z"]
    #
    # @return [Vector]
    # @raise [IndexError] if index is out of negative range.
    def fill(object, index = 0, length = nil)
      raise IndexError if index < -@size
      index += @size if index < 0
      length ||= @size - index # to the end of the array, if no length given

      if index < @size
        suffix = flatten_suffix(@root, @levels * BITS_PER_LEVEL, index, [])
        suffix.fill(object, 0, length)
      elsif index == @size
        suffix = Array.new(length, object)
      else
        suffix = Array.new(index - @size, nil).concat(Array.new(length, object))
        index = @size
      end

      replace_suffix(index, suffix)
    end

    # When invoked with a block, yields all combinations of length `n` of items
    # from the `Vector`, and then returns `self`. There is no guarantee about
    # which order the combinations will be yielded.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @example
    #   v = Immutable::Vector[5, 6, 7, 8]
    #   v.combination(3) { |c| puts "Combination: #{c}" }
    #
    #   Combination: [5, 6, 7]
    #   Combination: [5, 6, 8]
    #   Combination: [5, 7, 8]
    #   Combination: [6, 7, 8]
    #   #=> Immutable::Vector[5, 6, 7, 8]
    #
    # @return [self, Enumerator]
    def combination(n)
      return enum_for(:combination, n) if not block_given?
      return self if n < 0 || @size < n
      if n == 0
        yield []
      elsif n == 1
        each { |item| yield [item] }
      elsif n == @size
        yield to_a
      else
        combos = lambda do |result,index,remaining|
          while @size - index > remaining
            if remaining == 1
              yield result.dup << get(index)
            else
              combos[result.dup << get(index), index+1, remaining-1]
            end
            index += 1
          end
          index.upto(@size-1) { |i| result << get(i) }
          yield result
        end
        combos[[], 0, n]
      end
      self
    end

    # When invoked with a block, yields all repeated combinations of length `n` of
    # items from the `Vector`, and then returns `self`. A "repeated combination" is
    # one in which any item from the `Vector` can appear consecutively any number of
    # times.
    #
    # There is no guarantee about which order the combinations will be yielded in.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @example
    #   v = Immutable::Vector[5, 6, 7, 8]
    #   v.repeated_combination(2) { |c| puts "Combination: #{c}" }
    #
    #   Combination: [5, 5]
    #   Combination: [5, 6]
    #   Combination: [5, 7]
    #   Combination: [5, 8]
    #   Combination: [6, 6]
    #   Combination: [6, 7]
    #   Combination: [6, 8]
    #   Combination: [7, 7]
    #   Combination: [7, 8]
    #   Combination: [8, 8]
    #   # => Immutable::Vector[5, 6, 7, 8]
    #
    # @return [self, Enumerator]
    def repeated_combination(n)
      return enum_for(:repeated_combination, n) if not block_given?
      if n < 0
        # yield nothing
      elsif n == 0
        yield []
      elsif n == 1
        each { |item| yield [item] }
      elsif @size == 0
        # yield nothing
      else
        combos = lambda do |result,index,remaining|
          while index < @size-1
            if remaining == 1
              yield result.dup << get(index)
            else
              combos[result.dup << get(index), index, remaining-1]
            end
            index += 1
          end
          item = get(index)
          remaining.times { result << item }
          yield result
        end
        combos[[], 0, n]
      end
      self
    end

    # Yields all permutations of length `n` of items from the `Vector`, and then
    # returns `self`. If no length `n` is specified, permutations of all elements
    # will be yielded.
    #
    # There is no guarantee about which order the permutations will be yielded in.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @example
    #   v = Immutable::Vector[5, 6, 7]
    #   v.permutation(2) { |p| puts "Permutation: #{p}" }
    #
    #   Permutation: [5, 6]
    #   Permutation: [5, 7]
    #   Permutation: [6, 5]
    #   Permutation: [6, 7]
    #   Permutation: [7, 5]
    #   Permutation: [7, 6]
    #   # => Immutable::Vector[5, 6, 7]
    #
    # @return [self, Enumerator]
    def permutation(n = @size)
      return enum_for(:permutation, n) if not block_given?
      if n < 0 || @size < n
        # yield nothing
      elsif n == 0
        yield []
      elsif n == 1
        each { |item| yield [item] }
      else
        used, result = [], []
        perms = lambda do |index|
          0.upto(@size-1) do |i|
            next if used[i]
            result[index] = get(i)
            if index < n-1
              used[i] = true
              perms[index+1]
              used[i] = false
            else
              yield result.dup
            end
          end
        end
        perms[0]
      end
      self
    end

    # When invoked with a block, yields all repeated permutations of length `n` of
    # items from the `Vector`, and then returns `self`. A "repeated permutation" is
    # one where any item from the `Vector` can appear any number of times, and in
    # any position (not just consecutively)
    #
    # If no length `n` is specified, permutations of all elements will be yielded.
    # There is no guarantee about which order the permutations will be yielded in.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @example
    #   v = Immutable::Vector[5, 6, 7]
    #   v.repeated_permutation(2) { |p| puts "Permutation: #{p}" }
    #
    #   Permutation: [5, 5]
    #   Permutation: [5, 6]
    #   Permutation: [5, 7]
    #   Permutation: [6, 5]
    #   Permutation: [6, 6]
    #   Permutation: [6, 7]
    #   Permutation: [7, 5]
    #   Permutation: [7, 6]
    #   Permutation: [7, 7]
    #   # => Immutable::Vector[5, 6, 7]
    #
    # @return [self, Enumerator]
    def repeated_permutation(n = @size)
      return enum_for(:repeated_permutation, n) if not block_given?
      if n < 0
        # yield nothing
      elsif n == 0
        yield []
      elsif n == 1
        each { |item| yield [item] }
      else
        result = []
        perms = lambda do |index|
          0.upto(@size-1) do |i|
            result[index] = get(i)
            if index < n-1
              perms[index+1]
            else
              yield result.dup
            end
          end
        end
        perms[0]
      end
      self
    end

    # Cartesian product or multiplication.
    #
    # @overload product(*vectors)
    #   Return a `Vector` of all combinations of elements from this `Vector` and each
    #   of the given vectors or arrays. The length of the returned `Vector` is the product
    #   of `self.size` and the size of each argument vector or array.
    #   @example
    #     v1 = Immutable::Vector[1, 2, 3]
    #     v2 = Immutable::Vector["A", "B"]
    #     v1.product(v2)
    #     # => [[1, "A"], [1, "B"], [2, "A"], [2, "B"], [3, "A"], [3, "B"]]
    # @overload product
    #   Return the result of multiplying all the items in this `Vector` together.
    #
    #   @example
    #     Immutable::Vector[1, 2, 3, 4, 5].product  # => 120
    #
    # @return [Vector]
    def product(*vectors)
      # if no vectors passed, return "product" as in result of multiplying all items
      return super if vectors.empty?

      vectors.unshift(self)

      if vectors.any?(&:empty?)
        return block_given? ? self : []
      end

      counters = Array.new(vectors.size, 0)

      bump_counters = lambda do
        i = vectors.size-1
        counters[i] += 1
        while counters[i] == vectors[i].size
          counters[i] = 0
          i -= 1
          return true if i == -1 # we are done
          counters[i] += 1
        end
        false # not done yet
      end
      build_array = lambda do
        array = []
        counters.each_with_index { |index,i| array << vectors[i][index] }
        array
      end

      if block_given?
        loop do
          yield build_array[]
          return self if bump_counters[]
        end
      else
        result = []
        loop do
          result << build_array[]
          return result if bump_counters[]
        end
      end
    end

    # Assume all elements are vectors or arrays and transpose the rows and columns.
    # In other words, take the first element of each nested vector/array and gather
    # them together into a new `Vector`. Do likewise for the second, third, and so on
    # down to the end of each nested vector/array. Gather all the resulting `Vectors`
    # into a new `Vector` and return it.
    #
    # This operation is closely related to {#zip}. The result is almost the same as
    # calling {#zip} on the first nested vector/array with the others supplied as
    # arguments.
    #
    # @example
    #   Immutable::Vector[["A", 10], ["B", 20], ["C", 30]].transpose
    #   # => Immutable::Vector[Immutable::Vector["A", "B", "C"], Immutable::Vector[10, 20, 30]]
    #
    # @return [Vector]
    # @raise [IndexError] if elements are not of the same size.
    # @raise [TypeError] if an element does not respond to #size and #[]
    def transpose
      return self.class.empty if empty?
      result = Array.new(first.size) { [] }

      0.upto(@size-1) do |i|
        source = get(i)
        if source.size != result.size
          raise IndexError, "element size differs (#{source.size} should be #{result.size})"
        end

        0.upto(result.size-1) do |j|
          result[j].push(source[j])
        end
      end

      result.map! { |a| self.class.new(a) }
      self.class.new(result)
    rescue NoMethodError
      if any? { |x| !x.respond_to?(:size) || !x.respond_to?(:[]) }
        bad = find { |x| !x.respond_to?(:size) || !x.respond_to?(:[]) }
        raise TypeError, "'#{bad.inspect}' must respond to #size and #[] to be transposed"
      else
        raise
      end
    end

    # Finds a value from this `Vector` which meets the condition defined by the
    # provided block, using a binary search. The vector must already be sorted
    # with respect to the block.  See Ruby's `Array#bsearch` for details,
    # behaviour is equivalent.
    #
    # @example
    #   v = Immutable::Vector[1, 3, 5, 7, 9, 11, 13]
    #   # Block returns true/false for exact element match:
    #   v.bsearch { |e| e > 4 }      # => 5
    #   # Block returns number to match an element in 4 <= e <= 7:
    #   v.bsearch { |e| 1 - e / 4 }  # => 7
    #
    # @yield Once for at most `log n` elements, where `n` is the size of the
    #        vector. The exact elements and ordering are undefined.
    # @yieldreturn [Boolean] `true` if this element matches the criteria, `false` otherwise.
    # @yieldreturn [Integer] See `Array#bsearch` for details.
    # @yieldparam [Object] element element to be evaluated
    # @return [Object] The matched element, or `nil` if none found.
    # @raise TypeError if the block returns a non-numeric, non-boolean, non-nil
    #                  value.
    def bsearch
      return enum_for(:bsearch) if not block_given?
      low, high, result = 0, @size, nil
      while low < high
        mid = (low + ((high - low) >> 1))
        val = get(mid)
        v   = yield val
        if v.is_a? Numeric
          if v == 0
            return val
          elsif v > 0
            high = mid
          else
            low = mid + 1
          end
        elsif v == true
          result = val
          high = mid
        elsif !v
          low = mid + 1
        else
          raise TypeError, "wrong argument type #{v.class} (must be numeric, true, false, or nil)"
        end
      end
      result
    end

    # Return an empty `Vector` instance, of the same class as this one. Useful if you
    # have multiple subclasses of `Vector` and want to treat them polymorphically.
    #
    # @return [Vector]
    def clear
      self.class.empty
    end

    # Return a randomly chosen item from this `Vector`. If the vector is empty, return `nil`.
    #
    # @example
    #   Immutable::Vector[1, 2, 3, 4, 5].sample  # => 2
    #
    # @return [Object]
    def sample
      get(rand(@size))
    end

    # Return a new `Vector` with only the elements at the given `indices`, in the
    # order specified by `indices`. If any of the `indices` do not exist, `nil`s will
    # appear in their places.
    #
    # @example
    #   v = Immutable::Vector["A", "B", "C", "D", "E", "F"]
    #   v.values_at(2, 4, 5)   # => Immutable::Vector["C", "E", "F"]
    #
    # @param indices [Array] The indices to retrieve and gather into a new `Vector`
    # @return [Vector]
    def values_at(*indices)
      self.class.new(indices.map { |i| get(i) }.freeze)
    end

    # Find the index of an element, starting from the end of the vector.
    # Returns `nil` if no element is found.
    #
    # @overload rindex(obj)
    #   Return the index of the last element which is `#==` to `obj`.
    #
    #   @example
    #     v = Immutable::Vector[7, 8, 9, 7, 8, 9]
    #     v.rindex(8) # => 4
    #
    # @overload rindex
    #   Return the index of the last element for which the block returns true.
    #
    #   @yield [element] Once for each element, last to first, until the block
    #                    returns true.
    #   @example
    #     v = Immutable::Vector[7, 8, 9, 7, 8, 9]
    #     v.rindex { |e| e.even? }  # => 4
    #
    # @return [Integer]
    def rindex(obj = (missing_arg = true))
      i = @size - 1
      if missing_arg
        if block_given?
          reverse_each { |item| return i if yield item; i -= 1 }
          nil
        else
          enum_for(:rindex)
        end
      else
        reverse_each { |item| return i if item == obj; i -= 1 }
        nil
      end
    end

    # Assumes all elements are nested, indexable collections, and searches through them,
    # comparing `obj` with the first element of each nested collection. Return the
    # first nested collection which matches, or `nil` if none is found.
    # Behaviour is undefined when elements do not meet assumptions (i.e. are
    # not indexable collections).
    #
    # @example
    #   v = Immutable::Vector[["A", 10], ["B", 20], ["C", 30]]
    #   v.assoc("B")  # => ["B", 20]
    #
    # @param obj [Object] The object to search for
    # @return [Object]
    def assoc(obj)
      each do |array|
        next if !array.respond_to?(:[])
        return array if obj == array[0]
      end
      nil
    end

    # Assumes all elements are nested, indexable collections, and searches through them,
    # comparing `obj` with the second element of each nested collection. Return
    # the first nested collection which matches, or `nil` if none is found.
    # Behaviour is undefined when elements do not meet assumptions (i.e. are
    # not indexable collections).
    #
    # @example
    #   v = Immutable::Vector[["A", 10], ["B", 20], ["C", 30]]
    #   v.rassoc(20)  # => ["B", 20]
    #
    # @param obj [Object] The object to search for
    # @return [Object]
    def rassoc(obj)
      each do |array|
        next if !array.respond_to?(:[])
        return array if obj == array[1]
      end
      nil
    end

    # Return an `Array` with the same elements, in the same order. The returned
    # `Array` may or may not be frozen.
    #
    # @return [Array]
    def to_a
      if @levels == 0
        # When initializing a Vector with 32 or less items, we always make
        # sure @root is frozen, so we can return it directly here
        @root
      else
        flatten_node(@root, @levels * BITS_PER_LEVEL, [])
      end
    end
    alias to_ary to_a

    # Return true if `other` has the same type and contents as this `Vector`.
    #
    # @param other [Object] The collection to compare with
    # @return [Boolean]
    def eql?(other)
      return true if other.equal?(self)
      return false unless instance_of?(other.class) && @size == other.size
      @root.eql?(other.instance_variable_get(:@root))
    end

    # See `Object#hash`.
    # @return [Integer]
    def hash
      reduce(0) { |hash, item| (hash << 5) - hash + item.hash }
    end

    # Return `self`. Since this is an immutable object duplicates are
    # equivalent.
    # @return [Vector]
    def dup
      self
    end
    alias clone dup

    # @return [::Array]
    # @private
    def marshal_dump
      to_a
    end

    # @private
    def marshal_load(array)
      initialize(array.freeze)
    end

    private

    def traverse_depth_first(node, level, &block)
      return node.each(&block) if level == 0
      node.each { |child| traverse_depth_first(child, level - 1, &block) }
    end

    def reverse_traverse_depth_first(node, level, &block)
      return node.reverse_each(&block) if level == 0
      node.reverse_each { |child| reverse_traverse_depth_first(child, level - 1, &block) }
    end

    def leaf_node_for(node, bitshift, index)
      while bitshift > 0
        node = node[(index >> bitshift) & INDEX_MASK]
        bitshift -= BITS_PER_LEVEL
      end
      node
    end

    def update_root(index, item)
      root, levels = @root, @levels
      while index >= (1 << (BITS_PER_LEVEL * (levels + 1)))
        root = [root].freeze
        levels += 1
      end
      new_root = update_leaf_node(root, levels * BITS_PER_LEVEL, index, item)
      if new_root.equal?(root)
        self
      else
        self.class.alloc(new_root, @size > index ? @size : index + 1, levels)
      end
    end

    def update_leaf_node(node, bitshift, index, item)
      slot_index = (index >> bitshift) & INDEX_MASK
      if bitshift > 0
        old_child = node[slot_index] || []
        item = update_leaf_node(old_child, bitshift - BITS_PER_LEVEL, index, item)
      end
      existing_item = node[slot_index]
      if existing_item.equal?(item)
        node
      else
        node.dup.tap { |n| n[slot_index] = item }.freeze
      end
    end

    def flatten_range(node, bitshift, from, to)
      from_slot = (from >> bitshift) & INDEX_MASK
      to_slot   = (to   >> bitshift) & INDEX_MASK

      if bitshift == 0 # are we at the bottom?
        node.slice(from_slot, to_slot-from_slot+1)
      elsif from_slot == to_slot
        flatten_range(node[from_slot], bitshift - BITS_PER_LEVEL, from, to)
      else
        # the following bitmask can be used to pick out the part of the from/to indices
        #   which will be used to direct path BELOW this node
        mask   = ((1 << bitshift) - 1)
        result = []

        if from & mask == 0
          flatten_node(node[from_slot], bitshift - BITS_PER_LEVEL, result)
        else
          result.concat(flatten_range(node[from_slot], bitshift - BITS_PER_LEVEL, from, from | mask))
        end

        (from_slot+1).upto(to_slot-1) do |slot_index|
          flatten_node(node[slot_index], bitshift - BITS_PER_LEVEL, result)
        end

        if to & mask == mask
          flatten_node(node[to_slot], bitshift - BITS_PER_LEVEL, result)
        else
          result.concat(flatten_range(node[to_slot], bitshift - BITS_PER_LEVEL, to & ~mask, to))
        end

        result
      end
    end

    def flatten_node(node, bitshift, result)
      if bitshift == 0
        result.concat(node)
      elsif bitshift == BITS_PER_LEVEL
        node.each { |a| result.concat(a) }
      else
        bitshift -= BITS_PER_LEVEL
        node.each { |a| flatten_node(a, bitshift, result) }
      end
      result
    end

    def subsequence(from, length)
      return nil if from > @size || from < 0 || length < 0
      length = @size - from if @size < from + length
      return self.class.empty if length == 0
      self.class.new(flatten_range(@root, @levels * BITS_PER_LEVEL, from, from + length - 1))
    end

    def flatten_suffix(node, bitshift, from, result)
      from_slot = (from >> bitshift) & INDEX_MASK

      if bitshift == 0
        if from_slot == 0
          result.concat(node)
        else
          result.concat(node.slice(from_slot, 32)) # entire suffix of node. excess length is ignored by #slice
        end
      else
        mask = ((1 << bitshift) - 1)
        if from & mask == 0
          from_slot.upto(node.size-1) do |i|
            flatten_node(node[i], bitshift - BITS_PER_LEVEL, result)
          end
        elsif (child = node[from_slot])
          flatten_suffix(child, bitshift - BITS_PER_LEVEL, from, result)
          (from_slot+1).upto(node.size-1) do |i|
            flatten_node(node[i], bitshift - BITS_PER_LEVEL, result)
          end
        end
        result
      end
    end

    def replace_suffix(from, suffix)
      # new suffix can go directly after existing elements
      raise IndexError if from > @size
      root, levels = @root, @levels

      if (from >> (BITS_PER_LEVEL * (@levels + 1))) != 0
        # index where new suffix goes doesn't fall within current tree
        # we will need to deepen tree
        root = [root].freeze
        levels += 1
      end

      new_size = from + suffix.size
      root = replace_node_suffix(root, levels * BITS_PER_LEVEL, from, suffix)

      if !suffix.empty?
        levels.times { suffix = suffix.each_slice(32).to_a }
        root.concat(suffix)
        while root.size > 32
          root = root.each_slice(32).to_a
          levels += 1
        end
      else
        while root.size == 1 && levels > 0
          root = root[0]
          levels -= 1
        end
      end

      self.class.alloc(root.freeze, new_size, levels)
    end

    def replace_node_suffix(node, bitshift, from, suffix)
      from_slot = (from >> bitshift) & INDEX_MASK

      if bitshift == 0
        if from_slot == 0
          suffix.shift(32)
        else
          node.take(from_slot).concat(suffix.shift(32 - from_slot))
        end
      else
        mask = ((1 << bitshift) - 1)
        if from & mask == 0
          if from_slot == 0
            new_node = suffix.shift(32 * (1 << bitshift))
            while bitshift != 0
              new_node = new_node.each_slice(32).to_a
              bitshift -= BITS_PER_LEVEL
            end
            new_node
          else
            result = node.take(from_slot)
            remainder = suffix.shift((32 - from_slot) * (1 << bitshift))
            while bitshift != 0
              remainder = remainder.each_slice(32).to_a
              bitshift -= BITS_PER_LEVEL
            end
            result.concat(remainder)
          end
        elsif (child = node[from_slot])
          result = node.take(from_slot)
          result.push(replace_node_suffix(child, bitshift - BITS_PER_LEVEL, from, suffix))
          remainder = suffix.shift((31 - from_slot) * (1 << bitshift))
          while bitshift != 0
            remainder = remainder.each_slice(32).to_a
            bitshift -= BITS_PER_LEVEL
          end
          result.concat(remainder)
        else
          raise "Shouldn't happen"
        end
      end
    end
  end

  # The canonical empty `Vector`. Returned by `Vector[]` when
  # invoked with no arguments; also returned by `Vector.empty`. Prefer using this
  # one rather than creating many empty vectors using `Vector.new`.
  #
  # @private
  EmptyVector = Immutable::Vector.empty


  # `Immutable::Set` is a collection of unordered values with no duplicates. Testing whether
  # an object is present in the `Set` can be done in constant time. `Set` is also `Enumerable`, so you can
  # iterate over the members of the set with {#each}, transform them with {#map}, filter
  # them with {#select}, and so on. Some of the `Enumerable` methods are overridden to
  # return `immutable-ruby` collections.
  #
  # Like the `Set` class in Ruby's standard library, which we will call RubySet,
  # `Immutable::Set` defines equivalency of objects using `#hash` and `#eql?`. No two
  # objects with the same `#hash` code, and which are also `#eql?`, can coexist in the
  # same `Set`. If one is already in the `Set`, attempts to add another one will have
  # no effect.
  #
  # `Set`s have no natural ordering and cannot be compared using `#<=>`. However, they
  # define {#<}, {#>}, {#<=}, and {#>=} as shorthand for {#proper_subset?},
  # {#proper_superset?}, {#subset?}, and {#superset?} respectively.
  #
  # The basic set-theoretic operations {#union}, {#intersection}, {#difference}, and
  # {#exclusion} work with any `Enumerable` object.
  #
  # A `Set` can be created in either of the following ways:
  #
  #     Immutable::Set.new([1, 2, 3]) # any Enumerable can be used to initialize
  #     Immutable::Set['A', 'B', 'C', 'D']
  #
  # The latter 2 forms of initialization can be used with your own, custom subclasses
  # of `Immutable::Set`.
  #
  # Unlike RubySet, all methods which you might expect to "modify" an `Immutable::Set`
  # actually return a new set and leave the existing one unchanged.
  #
  # @example
  #   set1 = Immutable::Set[1, 2] # => Immutable::Set[1, 2]
  #   set2 = Immutable::Set[1, 2] # => Immutable::Set[1, 2]
  #   set1 == set2              # => true
  #   set3 = set1.add("foo")    # => Immutable::Set[1, 2, "foo"]
  #   set3 - set2               # => Immutable::Set["foo"]
  #   set3.subset?(set1)        # => false
  #   set1.subset?(set3)        # => true
  #
  class Set
    include Immutable::Enumerable

    class << self
      # Create a new `Set` populated with the given items.
      # @return [Set]
      def [](*items)
        items.empty? ? empty : new(items)
      end

      # Return an empty `Set`. If used on a subclass, returns an empty instance
      # of that class.
      #
      # @return [Set]
      def empty
        @empty ||= new
      end

      # "Raw" allocation of a new `Set`. Used internally to create a new
      # instance quickly after obtaining a modified {Trie}.
      #
      # @return [Set]
      # @private
      def alloc(trie = EmptyTrie)
        allocate.tap { |s| s.instance_variable_set(:@trie, trie) }.freeze
      end
    end

    def initialize(items=[])
      @trie = Trie.new(0)
      items.each { |item| @trie.put!(item, nil) }
      freeze
    end

    # Return `true` if this `Set` contains no items.
    # @return [Boolean]
    def empty?
      @trie.empty?
    end

    # Return the number of items in this `Set`.
    # @return [Integer]
    def size
      @trie.size
    end
    alias length size

    # Return a new `Set` with `item` added. If `item` is already in the set,
    # return `self`.
    #
    # @example
    #   Immutable::Set[1, 2, 3].add(4) # => Immutable::Set[1, 2, 4, 3]
    #   Immutable::Set[1, 2, 3].add(2) # => Immutable::Set[1, 2, 3]
    #
    # @param item [Object] The object to add
    # @return [Set]
    def add(item)
      include?(item) ? self : self.class.alloc(@trie.put(item, nil))
    end
    alias << add

    # If `item` is not a member of this `Set`, return a new `Set` with `item` added.
    # Otherwise, return `false`.
    #
    # @example
    #   Immutable::Set[1, 2, 3].add?(4) # => Immutable::Set[1, 2, 4, 3]
    #   Immutable::Set[1, 2, 3].add?(2) # => false
    #
    # @param item [Object] The object to add
    # @return [Set, false]
    def add?(item)
      !include?(item) && add(item)
    end

    # Return a new `Set` with `item` removed. If `item` is not a member of the set,
    # return `self`.
    #
    # @example
    #   Immutable::Set[1, 2, 3].delete(1)  # => Immutable::Set[2, 3]
    #   Immutable::Set[1, 2, 3].delete(99) # => Immutable::Set[1, 2, 3]
    #
    # @param item [Object] The object to remove
    # @return [Set]
    def delete(item)
      trie = @trie.delete(item)
      new_trie(trie)
    end

    # If `item` is a member of this `Set`, return a new `Set` with `item` removed.
    # Otherwise, return `false`.
    #
    # @example
    #   Immutable::Set[1, 2, 3].delete?(1)  # => Immutable::Set[2, 3]
    #   Immutable::Set[1, 2, 3].delete?(99) # => false
    #
    # @param item [Object] The object to remove
    # @return [Set, false]
    def delete?(item)
      include?(item) && delete(item)
    end

    # Call the block once for each item in this `Set`. No specific iteration order
    # is guaranteed, but the order will be stable for any particular `Set`. If
    # no block is given, an `Enumerator` is returned instead.
    #
    # @example
    #   Immutable::Set["Dog", "Elephant", "Lion"].each { |e| puts e }
    #   Elephant
    #   Dog
    #   Lion
    #   # => Immutable::Set["Dog", "Elephant", "Lion"]
    #
    # @yield [item] Once for each item.
    # @return [self, Enumerator]
    def each
      return to_enum if not block_given?
      @trie.each { |key, _| yield(key) }
      self
    end

    # Call the block once for each item in this `Set`. Iteration order will be
    # the opposite of {#each}. If no block is given, an `Enumerator` is
    # returned instead.
    #
    # @example
    #   Immutable::Set["Dog", "Elephant", "Lion"].reverse_each { |e| puts e }
    #   Lion
    #   Dog
    #   Elephant
    #   # => Immutable::Set["Dog", "Elephant", "Lion"]
    #
    # @yield [item] Once for each item.
    # @return [self]
    def reverse_each
      return enum_for(:reverse_each) if not block_given?
      @trie.reverse_each { |key, _| yield(key) }
      self
    end

    # Return a new `Set` with all the items for which the block returns true.
    #
    # @example
    #   Immutable::Set["Elephant", "Dog", "Lion"].select { |e| e.size >= 4 }
    #   # => Immutable::Set["Elephant", "Lion"]
    # @yield [item] Once for each item.
    # @return [Set]
    def select
      return enum_for(:select) unless block_given?
      trie = @trie.select { |key, _| yield(key) }
      new_trie(trie)
    end
    alias find_all select
    alias keep_if  select

    # Call the block once for each item in this `Set`. All the values returned
    # from the block will be gathered into a new `Set`. If no block is given,
    # an `Enumerator` is returned instead.
    #
    # @example
    #   Immutable::Set["Cat", "Elephant", "Dog", "Lion"].map { |e| e.size }
    #   # => Immutable::Set[8, 4, 3]
    #
    # @yield [item] Once for each item.
    # @return [Set]
    def map
      return enum_for(:map) if not block_given?
      return self if empty?
      self.class.new(super)
    end
    alias collect map

    # Return `true` if the given item is present in this `Set`. More precisely,
    # return `true` if an object with the same `#hash` code, and which is also `#eql?`
    # to the given object is present.
    #
    # @example
    #   Immutable::Set["A", "B", "C"].include?("B") # => true
    #   Immutable::Set["A", "B", "C"].include?("Z") # => false
    #
    # @param object [Object] The object to check for
    # @return [Boolean]
    def include?(object)
      @trie.key?(object)
    end
    alias member? include?

    # Return a member of this `Set`. The member chosen will be the first one which
    # would be yielded by {#each}. If the set is empty, return `nil`.
    #
    # @example
    #   Immutable::Set["A", "B", "C"].first # => "C"
    #
    # @return [Object]
    def first
      (entry = @trie.at(0)) && entry[0]
    end

    # Return a {SortedSet} which contains the same items as this `Set`, ordered by
    # the given comparator block.
    #
    # @example
    #   Immutable::Set["Elephant", "Dog", "Lion"].sort
    #   # => Immutable::SortedSet["Dog", "Elephant", "Lion"]
    #   Immutable::Set["Elephant", "Dog", "Lion"].sort { |a,b| a.size <=> b.size }
    #   # => Immutable::SortedSet["Dog", "Lion", "Elephant"]
    #
    # @yield [a, b] Any number of times with different pairs of elements.
    # @yieldreturn [Integer] Negative if the first element should be sorted
    #                        lower, positive if the latter element, or 0 if
    #                        equal.
    # @return [SortedSet]
    def sort(&comparator)
      SortedSet.new(to_a, &comparator)
    end

    # Return a {SortedSet} which contains the same items as this `Set`, ordered
    # by mapping each item through the provided block to obtain sort keys, and
    # then sorting the keys.
    #
    # @example
    #   Immutable::Set["Elephant", "Dog", "Lion"].sort_by { |e| e.size }
    #   # => Immutable::SortedSet["Dog", "Lion", "Elephant"]
    #
    # @yield [item] Once for each item to create the set, and then potentially
    #               again depending on what operations are performed on the
    #               returned {SortedSet}. As such, it is recommended that the
    #               block be a pure function.
    # @yieldreturn [Object] sort key for the item
    # @return [SortedSet]
    def sort_by(&mapper)
      SortedSet.new(to_a, &mapper)
    end

    # Return a new `Set` which contains all the members of both this `Set` and `other`.
    # `other` can be any `Enumerable` object.
    #
    # @example
    #   Immutable::Set[1, 2] | Immutable::Set[2, 3] # => Immutable::Set[1, 2, 3]
    #
    # @param other [Enumerable] The collection to merge with
    # @return [Set]
    def union(other)
      if other.is_a?(Immutable::Set)
        if other.size > size
          small_set_pairs = @trie
          large_set_trie = other.instance_variable_get(:@trie)
        else
          small_set_pairs = other.instance_variable_get(:@trie)
          large_set_trie = @trie
        end
      else
        if other.respond_to?(:lazy)
          small_set_pairs = other.lazy.map { |e| [e, nil] }
        else
          small_set_pairs = other.map { |e| [e, nil] }
        end
        large_set_trie = @trie
      end

      trie = large_set_trie.bulk_put(small_set_pairs)
      new_trie(trie)
    end
    alias | union
    alias + union
    alias merge union

    # Return a new `Set` which contains all the items which are members of both
    # this `Set` and `other`. `other` can be any `Enumerable` object.
    #
    # @example
    #   Immutable::Set[1, 2] & Immutable::Set[2, 3] # => Immutable::Set[2]
    #
    # @param other [Enumerable] The collection to intersect with
    # @return [Set]
    def intersection(other)
      if other.size < @trie.size
        if other.is_a?(Immutable::Set)
          trie = other.instance_variable_get(:@trie).select { |key, _| include?(key) }
        else
          trie = Trie.new(0)
          other.each { |obj| trie.put!(obj, nil) if include?(obj) }
        end
      else
        trie = @trie.select { |key, _| other.include?(key) }
      end
      new_trie(trie)
    end
    alias & intersection

    # Return a new `Set` with all the items in `other` removed. `other` can be
    # any `Enumerable` object.
    #
    # @example
    #   Immutable::Set[1, 2] - Immutable::Set[2, 3] # => Immutable::Set[1]
    #
    # @param other [Enumerable] The collection to subtract from this set
    # @return [Set]
    def difference(other)
      trie = if (@trie.size <= other.size) && (other.is_a?(Immutable::Set) || (defined?(::Set) && other.is_a?(::Set)))
        @trie.select { |key, _| !other.include?(key) }
      else
        @trie.bulk_delete(other)
      end
      new_trie(trie)
    end
    alias subtract difference
    alias - difference

    # Return a new `Set` which contains all the items which are members of this
    # `Set` or of `other`, but not both. `other` can be any `Enumerable` object.
    #
    # @example
    #   Immutable::Set[1, 2] ^ Immutable::Set[2, 3] # => Immutable::Set[1, 3]
    #
    # @param other [Enumerable] The collection to take the exclusive disjunction of
    # @return [Set]
    def exclusion(other)
      ((self | other) - (self & other))
    end
    alias ^ exclusion

    # Return `true` if all items in this `Set` are also in `other`.
    #
    # @example
    #   Immutable::Set[2, 3].subset?(Immutable::Set[1, 2, 3]) # => true
    #
    # @param other [Set]
    # @return [Boolean]
    def subset?(other)
      return false if other.size < size

      # This method has the potential to be very slow if 'other' is a large Array, so to avoid that,
      #   we convert those Arrays to Sets before checking presence of items
      # Time to convert Array -> Set is linear in array.size
      # Time to check for presence of all items in an Array is proportional to set.size * array.size
      # Note that both sides of that equation have array.size -- hence those terms cancel out,
      #   and the break-even point is solely dependent on the size of this collection
      # After doing some benchmarking to estimate the constants, it appears break-even is at ~190 items
      # We also check other.size, to avoid the more expensive #is_a? checks in cases where it doesn't matter
      #
      if other.size >= 150 && @trie.size >= 190 && !(other.is_a?(Immutable::Set) || other.is_a?(::Set))
        other = ::Set.new(other)
      end
      all? { |item| other.include?(item) }
    end
    alias <= subset?

    # Return `true` if all items in `other` are also in this `Set`.
    #
    # @example
    #   Immutable::Set[1, 2, 3].superset?(Immutable::Set[2, 3]) # => true
    #
    # @param other [Set]
    # @return [Boolean]
    def superset?(other)
      other.subset?(self)
    end
    alias >= superset?

    # Returns `true` if `other` contains all the items in this `Set`, plus at least
    # one item which is not in this set.
    #
    # @example
    #   Immutable::Set[2, 3].proper_subset?(Immutable::Set[1, 2, 3])    # => true
    #   Immutable::Set[1, 2, 3].proper_subset?(Immutable::Set[1, 2, 3]) # => false
    #
    # @param other [Set]
    # @return [Boolean]
    def proper_subset?(other)
      return false if other.size <= size
      # See comments above
      if other.size >= 150 && @trie.size >= 190 && !(other.is_a?(Immutable::Set) || other.is_a?(::Set))
        other = ::Set.new(other)
      end
      all? { |item| other.include?(item) }
    end
    alias < proper_subset?

    # Returns `true` if this `Set` contains all the items in `other`, plus at least
    # one item which is not in `other`.
    #
    # @example
    #   Immutable::Set[1, 2, 3].proper_superset?(Immutable::Set[2, 3])    # => true
    #   Immutable::Set[1, 2, 3].proper_superset?(Immutable::Set[1, 2, 3]) # => false
    #
    # @param other [Set]
    # @return [Boolean]
    def proper_superset?(other)
      other.proper_subset?(self)
    end
    alias > proper_superset?

    # Return `true` if this `Set` and `other` do not share any items.
    #
    # @example
    #   Immutable::Set[1, 2].disjoint?(Immutable::Set[8, 9]) # => true
    #
    # @param other [Set]
    # @return [Boolean]
    def disjoint?(other)
      if other.size <= size
        other.each { |item| return false if include?(item) }
      else
        # See comment on #subset?
        if other.size >= 150 && @trie.size >= 190 && !(other.is_a?(Immutable::Set) || other.is_a?(::Set))
          other = ::Set.new(other)
        end
        each { |item| return false if other.include?(item) }
      end
      true
    end

    # Return `true` if this `Set` and `other` have at least one item in common.
    #
    # @example
    #   Immutable::Set[1, 2].intersect?(Immutable::Set[2, 3]) # => true
    #
    # @param other [Set]
    # @return [Boolean]
    def intersect?(other)
      !disjoint?(other)
    end

    # Recursively insert the contents of any nested `Set`s into this `Set`, and
    # remove them.
    #
    # @example
    #   Immutable::Set[Immutable::Set[1, 2], Immutable::Set[3, 4]].flatten
    #   # => Immutable::Set[1, 2, 3, 4]
    #
    # @return [Set]
    def flatten
      reduce(self.class.empty) do |set, item|
        next set.union(item.flatten) if item.is_a?(Set)
        set.add(item)
      end
    end

    alias group group_by
    alias classify group_by

    # Return a randomly chosen item from this `Set`. If the set is empty, return `nil`.
    #
    # @example
    #   Immutable::Set[1, 2, 3, 4, 5].sample # => 3
    #
    # @return [Object]
    def sample
      empty? ? nil : @trie.at(rand(size))[0]
    end

    # Return an empty `Set` instance, of the same class as this one. Useful if you
    # have multiple subclasses of `Set` and want to treat them polymorphically.
    #
    # @return [Set]
    def clear
      self.class.empty
    end

    # Return true if `other` has the same type and contents as this `Set`.
    #
    # @param other [Object] The object to compare with
    # @return [Boolean]
    def eql?(other)
      return true if other.equal?(self)
      return false if not instance_of?(other.class)
      other_trie = other.instance_variable_get(:@trie)
      return false if @trie.size != other_trie.size
      @trie.each do |key, _|
        return false if !other_trie.key?(key)
      end
      true
    end
    alias == eql?

    # See `Object#hash`.
    # @return [Integer]
    def hash
      reduce(0) { |hash, item| (hash << 5) - hash + item.hash }
    end

    # Return `self`. Since this is an immutable object duplicates are
    # equivalent.
    # @return [Set]
    def dup
      self
    end
    alias clone dup

    undef :"<=>" # Sets are not ordered, so Enumerable#<=> will give a meaningless result
    undef :each_index # Set members cannot be accessed by 'index', so #each_index is not meaningful

    # Return `self`.
    #
    # @return [self]
    def to_set
      self
    end

    # @private
    def marshal_dump
      output = {}
      each do |key|
        output[key] = nil
      end
      output
    end

    # @private
    def marshal_load(dictionary)
      @trie = dictionary.reduce(EmptyTrie) do |trie, key_value|
        trie.put(key_value.first, nil)
      end
    end

    private

    def new_trie(trie)
      if trie.empty?
        self.class.empty
      elsif trie.equal?(@trie)
        self
      else
        self.class.alloc(trie)
      end
    end
  end

  # The canonical empty `Set`. Returned by `Set[]` when
  # invoked with no arguments; also returned by `Set.empty`. Prefer using this
  # one rather than creating many empty sets using `Set.new`.
  #
  # @private
  EmptySet = Immutable::Set.empty
end
