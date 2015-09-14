Immutable Ruby
==============

Efficient, immutable, and thread-safe collection classes for Ruby.

The `immutable-ruby` gem provides 6 [Persistent Data Structures][PDS]: {Immutable::Hash Hash}, {Immutable::Vector Vector}, {Immutable::Set Set}, {Immutable::SortedSet SortedSet}, {Immutable::List List}, and {Immutable::Deque Deque} (which works as an immutable queue or stack).

Whenever you modify an `Immutable` collection, the original is preserved and a modified copy is returned. This makes them inherently thread-safe and shareable. At the same time, they remain CPU and memory-efficient by sharing between copies. (However, you *can* still mutate objects stored in these collections. We don't recommend that you do this, unless you are sure you know what you are doing.)

`Immutable` collections are almost always closed under a given operation. That is, whereas Ruby's collection methods always return arrays, `Immutable` collections will return an instance of the same class wherever possible.

Where possible, `Immutable` collections offer an interface compatible with Ruby's built-in `Hash`, `Array`, `Set`, and `Enumerable`, to ease code migration. Also, `Immutable` methods accept regular Ruby collections as arguments, so code which uses `Immutable` can easily interoperate with your other Ruby code.

And lastly, `Immutable` lists are lazy, making it possible to (among other things)
process "infinitely large" lists.

[PDS]: http://en.wikipedia.org/wiki/Persistent_data_structure


Using
=====

To make the collection classes available in your code:

``` ruby
require "immutable"
```

Or if you prefer to only pull in certain collection types:

``` ruby
require "immutable/hash"
require "immutable/vector"
require "immutable/set"
require "immutable/sorted_set"
require "immutable/list"
require "immutable/deque"
```

<h2>Hash <span style="font-size:0.7em">({Immutable::Hash API Documentation}</a>)</span></h2>

Constructing an `Immutable::Hash` is almost as simple as a regular one:

``` ruby
person = Immutable::Hash[name: "Simon", gender: :male]
# => Immutable::Hash[:name => "Simon", :gender => :male]
```

Accessing the contents will be familiar to you:

``` ruby
person[:name]                       # => "Simon"
person.get(:gender)                 # => :male
```

Updating the contents is a little different than you are used to:

``` ruby
friend = person.put(:name, "James") # => Immutable::Hash[:name => "James", :gender => :male]
person                              # => Immutable::Hash[:name => "Simon", :gender => :male]
friend[:name]                       # => "James"
person[:name]                       # => "Simon"
```

As you can see, updating the hash returned a copy, leaving the original intact. Similarly, deleting a key returns yet another copy:

``` ruby
male = person.delete(:name)         # => Immutable::Hash[:gender => :male]
person                              # => Immutable::Hash[:name => "Simon", :gender => :male]
male.key?(:name)                    # => false
person.key?(:name)                  # => true
```

Since it is immutable, `Immutable::Hash` doesn't provide an assignment (`Hash#[]=`) method. However, `Hash#put` can accept a block which transforms the value associated with a given key:

``` ruby
counters.put(:odds) { |value| value + 1 } # => Immutable::Hash[:odds => 1, :evens => 0]
```

Or more succinctly:

``` ruby
counters.put(:odds, &:next)         # => {:odds => 1, :evens => 0}
```

This is just the beginning; see the {Immutable::Hash API documentation} for details on all `Hash` methods.


<h2>Vector <span style="font-size:0.7em">({Immutable::Vector API Documentation})</span></h2>

A `Vector` is an integer-indexed collection much like an immutable `Array`. Examples:

``` ruby
vector = Immutable::Vector[1, 2, 3, 4] # => Immutable::Vector[1, 2, 3, 4]
vector[0]                              # => 1
vector[-1]                             # => 4
vector.set(1, :a)                      # => Immutable::Vector[1, :a, 3, 4]
vector.add(:b)                         # => Immutable::Vector[1, 2, 3, 4, :b]
vector.insert(2, :a, :b)               # => Immutable::Vector[1, 2, :a, :b, 3, 4]
vector.delete_at(0)                    # => Immutable::Vector[2, 3, 4]
```

Other `Array`-like methods like `#select`, `#map`, `#shuffle`, `#uniq`, `#reverse`,
`#rotate`, `#flatten`, `#sort`, `#sort_by`, `#take`, `#drop`, `#take_while`,
`#drop_while`, `#fill`, `#product`, and `#transpose` are also supported. See the
{Immutable::Vector API documentation} for details on all `Vector` methods.


<h2>Set <span style="font-size:0.7em">({Immutable::Set API Documentation})</span></h2>

A `Set` is an unordered collection of values with no duplicates. It is much like the Ruby standard library's `Set`, but immutable. Examples:

``` ruby
set = Immutable::Set[:red, :blue, :yellow] # => Immutable::Set[:red, :blue, :yellow]
set.include? :red                          # => true
set.add :green                             # => Immutable::Set[:red, :blue, :yellow, :green]
set.delete :blue                           # => Immutable::Set[:red, :yellow]
set.superset? Immutable::Set[:red, :blue]  # => true
set.union([:red, :blue, :pink])            # => Immutable::Set[:red, :blue, :yellow, :pink]
set.intersection([:red, :blue, :pink])     # => Immutable::Set[:red, :blue]
```

Like most immutable methods, the set-theoretic methods `#union`, `#intersection`, `#difference`, and `#exclusion` (aliased as `#|`, `#&`, `#-`, and `#^`) all work with regular Ruby collections, or indeed any `Enumerable` object. So just like all the other immutable collections, `Immutable::Set` can easily be used in combination with "ordinary" Ruby code.

See the {Immutable::Set API documentation} for details on all `Set` methods.


<h2>SortedSet <span style="font-size:0.7em">({Immutable::SortedSet API Documentation})</span></h2>

A `SortedSet` is like a `Set`, but ordered. You can do everything with it that you can
do with a `Set`. Additionally, you can get the `#first` and `#last` item, or retrieve
an item using an integral index:

``` ruby
set = Immutable::SortedSet['toast', 'jam', 'bacon'] # => Immutable::SortedSet["bacon", "jam", "toast"]
set.first                                           # => "bacon"
set.last                                            # => "toast"
set[1]                                              # => "jam"
```

You can also specify the sort order using a block:

``` ruby
Immutable::SortedSet.new(['toast', 'jam', 'bacon']) { |a,b| b <=> a }
Immutable::SortedSet.new(['toast', 'jam', 'bacon']) { |str| str.chars.last }
```

See the {Immutable::SortedSet API documentation} for details on all `SortedSet` methods.


<h2>List <span style="font-size:0.7em">({Immutable::List API Documentation})</span></h2>

`Immutable::List`s have a *head* (the value at the front of the list), and a *tail* (a list of the remaining items):

``` ruby
list = Immutable::List[1, 2, 3]
list.head                    # => 1
list.tail                    # => Immutable::List[2, 3]
```

Add to a list with {Immutable::List#add}:

``` ruby
original = Immutable::List[1, 2, 3]
copy = original.add(0)      # => Immutable::List[0, 1, 2, 3]
```

Notice how modifying a list actually returns a new list.


### Laziness

`Immutable::List` is lazy where possible. It tries to defer processing items until absolutely necessary. For example, given a crude function to detect prime numbers:

``` ruby
def prime?(number)
  2.upto(Math.sqrt(number).round) do |integer|
    return false if (number % integer).zero?
  end
  true
end
```

The following code will only call `#prime?` as many times as necessary to generate the first 3 prime numbers between 10,000 and 1,000,000:

``` ruby
Immutable.interval(10_000, 1_000_000).select do |number|
  prime?(number)
end.take(3)
  # => 0.0009s
```

Compare that to the conventional equivalent which needs to calculate all possible values in the range before taking the first three:

``` ruby
(10000..1000000).select do |number|
  prime?(number)
end.take(3)
  # => 10s
```

### Construction

Besides `Immutable::List[]` there are other ways to construct lists:

  - {Immutable.interval Immutable.interval(from, to)} creates a lazy list
    equivalent to a list containing all the values between
    `from` and `to` without actually creating a list that big.

  - {Immutable.stream Immutable.stream { ... }} allows you to creates infinite
    lists. Each time a new value is required, the supplied
    block is called. To generate a list of integers you could do:

    ``` ruby
    count = 0
    Immutable.stream { count += 1 }
    ```

  - {Immutable.repeat Immutable.repeat(x)} creates an infinite list with `x` as the
    value for every element.

  - {Immutable.replicate Immutable.replicate(n, x)} creates a list of size `n` with
    `x` as the value for every element.

  - {Immutable.iterate Immutable.iterate(x) { |x| ... }} creates an infinite
    list where the first item is calculated by applying the
    block on the initial argument, the second item by applying
    the function on the previous result and so on. For
    example, a simpler way to generate a list of integers
    would be:

    ``` ruby
    Immutable.iterate(1) { |i| i + 1 }
    ```

    or even more succinctly:

    ``` ruby
    Immutable.iterate(1, &:next)
    ```
  - {Immutable::List.empty} returns an empty list, which you can
    build up using repeated calls to {Immutable::List#add #add} or other `List` methods.


### Core Extensions

{Enumerable#to_list} will convert any existing `Enumerable` to a list, so you can
slowly transition from built-in collection classes to immutable.

{IO#to_list} enables lazy processing of huge files. For example, imagine the
following code to process a 100MB file:

``` ruby
require 'immutable/core_ext'

File.open("my_100_mb_file.txt") do |file|
  lines = []
  file.each_line do |line|
    break if lines.size == 10
    lines << line.chomp.downcase.reverse
  end
end
```

Compare to the following more functional version:

``` ruby
File.open("my_100_mb_file.txt") do |file|
  file.map(&:chomp).map(&:downcase).map(&:reverse).take(10)
end
```

Unfortunately, though the second example reads nicely it takes many seconds to run (compared with milliseconds for the first) even though we're only interested in the first ten lines. Using `#to_list` we can get the running time back comparable to the imperative version.

``` ruby
File.open("my_100_mb_file.txt") do |file|
  file.to_list.map(&:chomp).map(&:downcase).map(&:reverse).take(10)
end
```

This is possible because `IO#to_list` creates a lazy list whereby each line is
only ever read and processed as needed, in effect converting it to the first
example.

See the {Immutable::List API documentation} for details on all List methods.


<h2>Deque <span style="font-size:0.7em">({Immutable::Deque API Documentation})</span></h2>

A `Deque` (or "double-ended queue") is an ordered collection, which allows you to push and pop items from both front and back. This makes it perfect as an immutable stack *or* queue. Examples:

``` ruby
deque = Immutable::Deque[1, 2, 3] # => Immutable::Deque[1, 2, 3]
deque.first                       # 1
deque.last                        # 3
deque.pop                         # => Immutable::Deque[1, 2]
deque.push(:a)                    # => Immutable::Deque[1, 2, 3, :a]
deque.shift                       # => Immutable::Deque[2, 3]
deque.unshift(:a)                 # => Immutable::Deque[:a, 1, 2, 3]
```

Of course, you can do the same thing with a `Vector`, but a `Deque` is more efficient. See the {Immutable::Deque API documentation} for details on all Deque methods.


Other Reading
=============

- The structure which is used for `Immutable::Hash` and `Immutable::Set`: [Hash Array Mapped Tries][HAMT]
- An interesting perspective on why immutability itself is inherently a good thing: Matthias Felleisen's [Function Objects presentation][FO].
- The `immutable-ruby` {file:FAQ.md FAQ}
- {file:CONDUCT.md Contributor's Code of Conduct}
- {file:LICENSE License}

[HAMT]: http://lampwww.epfl.ch/papers/idealhashtrees.pdf
[FO]: http://www.ccs.neu.edu/home/matthias/Presentations/ecoop2004.pdf
