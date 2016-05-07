# This code is derived from the SOM benchmarks, see AUTHORS.md file.
#
# Copyright (c) 2015-2016 Stefan Marr <git@stefan-marr.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

INITIAL_SIZE = 10
INITIAL_CAPACITY = 16

class Pair
  attr_accessor :key
  attr_accessor :value

  def initialize(key, value)
    @key   = key
    @value = value
  end
end

class Vector

  def self.with(elem)
    new_vector = self.new(1)
    new_vector.append(elem)
    new_vector
  end

  def initialize(size = 50)
    @storage   = Array.new(size)
    @first_idx = 0
    @last_idx  = 0
  end

  def at(idx)
    @storage[idx]
  end

  def append(elem)
    if @last_idx >= @storage.size
      # Need to expand capacity first
      new_storage = Array.new(2 * @storage.size)
      @storage.each_index { | i |
        new_storage[i] = @storage[i]
      }
      @storage = new_storage
    end

    @storage[@last_idx] = elem
    @last_idx += 1
    self
  end

  def empty?
    @last_idx == @first_idx
  end

  def each # &block
    (@first_idx..(@last_idx - 1)).each { | i |
      yield @storage[i]
    }
  end

  def has_some
    (@first_idx..(@last_idx - 1)).each { | i |
      if yield @storage[i]
        return true
      end
    }
    false
  end

  def get_one
    (@first_idx..(@last_idx - 1)).each { | i |
      e = @storage[i]
      if yield e
        return e
      end
    }
    nil
  end

  def remove_first
    if empty?
      return nil
    end

    @first_idx += 1
    @storage[@first_idx - 1]
  end

  def remove(obj)
    new_array = Array.new(capacity)
    new_last = 0
    found = false

    each { | it |
      if it.equal? obj
        found = true
      else
        new_array[new_last] = it
        new_last += 1
      end
    }

    @storage  = new_array
    @last_idx = new_last
    @first_idx = 0
    found
  end

  def remove_all
    @storage = Array.new(@storage.size)
  end

  def size
    @last_idx - @first_idx
  end

  def capacity
    @storage.size
  end

  def sort(&block)
    # Make the argument, block, be the criterion for ordering elements of
    # the receiver.
    # Sort blocks with side effects may not work right.
    if size > 0
      sort_range(@first_idx, @last_idx - 1, &block)
    end
  end

  def sort_range(i, j)  # &block
    # Sort elements i through j of self to be non-descending according to sortBlock.
    unless block_given?
      default_sort(i, j)
    end

    # The prefix d means the data at that index.

    n = j + 1 - i
    if n <= 1
      return self  # Nothing to sort
    end

    # Sort di, dj
    di = @storage[i]
    dj = @storage[j]

    # i.e., should di precede dj?
    unless yield di, dj
      @storage.swap(i, j)
      tt = di
      di = dj
      dj = tt
    end

    # NOTE: For DeltaBlue, this is never reached.
    if n > 2  # More than two elements.
      ij  = ((i + j) / 2).floor  # ij is the midpoint of i and j.
      dij = @storage[ij]         # Sort di,dij,dj.  Make dij be their median.

      if yield di, dij           # i.e. should di precede dij?
        unless yield dij, dj     # i.e., should dij precede dj?
          @storage.swap(j, ij)
          dij = dj
        end
      else                       # i.e. di should come after dij
        @storage.swap(i, ij)
        dij = di
      end

      if n > 3  # More than three elements.
        # Find k>i and l<j such that dk,dij,dl are in reverse order.
        # Swap k and l.  Repeat this procedure until k and l pass each other.
        k = i
        l = j - 1

        while (
          while k <= l && (yield dij, @storage[l])  # i.e. while dl succeeds dij
            l -= 1
          end

          k += 1
          while k <= l && (yield @storage[k], dij)  # i.e. while dij succeeds dk
            k += 1
          end
          k <= l)
          @storage.swap(k, l)
        end

        # Now l < k (either 1 or 2 less), and di through dl are all less than or equal to dk
        # through dj.  Sort those two segments.

        sort_range(i, l, &block)
        sort_range(k, j, &block)
      end
    end
  end
end

class Set
  def initialize(size = INITIAL_SIZE)
    @items = Vector.new(size)
  end

  def size
    @items.size
  end

  def each(&block)
    @items.each(&block)
  end

  def has_some(&block)
    @items.has_some(&block)
  end

  def get_one(&block)
    @items.get_one(&block)
  end

  def add(obj)
    unless contains(obj)
      @items.append(obj)
    end
  end

  def collect # &block
    coll = Vector.new
    each { | e | coll.append(yield e) }
    coll
  end

  def contains(obj)
    has_some { | it | it == obj }
  end
end

class IdentitySet < Set
  def contains(obj)
    has_some { | it | it.equal? obj }
  end
end

class Entry
  attr_reader :hash, :key
  attr_accessor :value, :next

  def initialize(hash, key, value, next_)
    @hash  = hash
    @key   = key
    @value = value
    @next  = next_
  end

  def match(hash, key)
    @hash == hash && @key == key
  end
end

class Dictionary
  attr_reader :size

  def initialize(size = INITIAL_CAPACITY)
    @buckets = Array.new(size)
    @size    = 0
  end

  def hash(key)
    if key.nil?
      return 0
    end

    hash = key.hash
    hash ^ hash >> 16
  end

  def empty?
    @size == 0
  end

  def get_bucket_idx(hash)
    (@buckets.size - 1) & hash
  end

  def get_bucket(hash)
    @buckets[get_bucket_idx(hash)]
  end

  def at(key)
    hash = hash(key)
    e = get_bucket(hash)

    until e.nil?
      if e.match(hash, key)
        return e.value
      end
      e = e.next
    end
    nil
  end

  def contains_key(key)
    hash = hash(key)
    e = get_bucket(hash)

    until e.nil?
      if e.match(hash, key)
        return true
      end
      e = e.next
    end
    false
  end

  def at_put(key, value)
    hash = hash(key)
    i = get_bucket_idx(hash)
    current = @buckets[i]

    if current.nil?
      @buckets[i] = new_entry(key, value, hash)
    else
      insert_bucket_entry(key, value, hash, current)
    end

    @size += 1
    if @size > @buckets.size
      resize
    end
  end

  def new_entry(key, value, hash)
    Entry.new(hash, key, value, nil)
  end

  def insert_bucket_entry(key, value, hash, head)
    current = head

    while true
      if current.match(hash, key)
        current.value = value
        return
      end
      if current.next.nil?
        current.next = new_entry(key, value, hash)
        return
      end
      current = current.next
    end
  end

  def resize
    old_storage = @buckets
    @buckets = Array.new(old_storage.size * 2)
    transfer_entries(old_storage)
  end

  def transfer_entries(old_storage)
    old_storage.each_with_index { |current, i|
      unless current.nil?
        old_storage[i] = nil

        if current.next.nil?
          @buckets[current.hash & (@buckets.size - 1)] = current
        else
          split_bucket(old_storage, i, current)
        end
      end
    }
  end

  def split_bucket(old_storage, i, head)
    lo_head = nil, lo_tail = nil
    hi_head = nil, hi_tail = nil
    current = head

    until current.nil?
      if (current.hash & old_storage.size) == 0
        if lo_tail.nil?
          lo_head = current
        else
          lo_tail.next = current
        end
        lo_tail = current
      else
        if hi_tail.nil?
          hi_head = current
        else
          hi_tail.next = current
        end
        hi_tail = current
      end
      current = current.next
    end

    unless lo_tail.nil?
      lo_tail.next = nil
      @buckets[i] = lo_head
    end
    unless hi_tail.nil?
      hi_tail.next = nil
      @buckets[i + old_storage.size] = hi_head
    end
  end

  def remove_all
    @buckets = Array.new(@buckets.size)
    @size = 0
  end

  def keys
    keys = Vector.new(@size)
    @buckets.each_index { |i|
      current = @buckets[i]
      until current.nil?
        keys.append(current.key)
        current = current.next
      end
    }
    keys
  end

  def values
    vals = Vector.new(@size)
    @buckets.each_index { |i|
      current = @buckets[i]
      until current.nil?
        vals.append(current.value)
        current = current.next
      end
    }
    vals
  end
end

class IdEntry < Entry
  def match(hash, key)
    @hash == hash && (@key.equal? key)
  end
end

class IdentityDictionary < Dictionary
  def new_entry(key, value, hash)
    IdEntry.new(hash, key, value, nil)
  end
end

class Random
  def initialize
    @seed = 74755
  end

  def next
    @seed = ((@seed * 1309) + 13849) & 65535
  end
end
