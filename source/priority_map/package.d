/**
Copyright: Copyright 2025 — 2026 Aya Partridge.
	Distributed under the GNU Lesser General Public License, Version 3.
	(See accompanying file LICENSE.md or copy at https://www.gnu.org/licenses/lgpl-3.0.md)
*/
module priority_map;

import memterface.allocator.gc;
import pairing_heap;

/**
A mixture of a hash map and a priority queue. You can insert, get, and
remove elements by key, and by maximum value with great efficiency.

By default, the maximum value comes first (e.g. a max-heap). To make the minimum
value come first, set the `less` function to `"a.value > b.value"`.

It can also be used more like a set than a hash map by setting `Value` to `void`,
and elements can be sorted by key by using `.key` instead of `.value` in the `less` function.

When copied, the original will be nullified. This is to prevent multiple `PriorityMap`s referencing
the same `PairingHeap`. If you wish to pass a `PriorityMap` to a function without it being nullified,
then it should be passed as `ref`, as a pointer, or be returned from the function.

Params:
	Key = The key to index elements with.
	Value = The value of each element. May be `void`.
	less = A binary function to compare elements with.
	PairingHeapAllocator = The allocator type used by the internal `PairingHeap`.
	HashMap = A template of the type of hash map to use internally. Pass `void` to use D's built-in associative arrays.
		The hash map must support at least `.opIndex(Key)`, `.opIndexAssign(Value, Key)`, and `.opBinaryRight!"in"(Key)`.
		Its template parameters must start with `(Key, Value)`, with no non-optional parameters thereafter. If your hash map's
		template parameters don't meet this requirement then make an alias: `alias AliasedMap(Key,Value) = MyMap!(Value,Key,100)`
*/
struct PriorityMap(Key, Value, alias less="a.value < b.value", PairingHeapAllocator=GCAllocator, alias HashMap=void){
	struct Pair{
		Key key;
		static if(!is(Value == void))
		Value value;
	}
	alias KeyValue = Pair;
	alias Heap = PairingHeap!(Pair, less, PairingHeapAllocator);
	static if(is(HashMap == void)){
		alias Map = Heap.Node*[Key];
	}else{
		alias Map = HashMap!(Key, Heap.Node*);
	}
	private Heap _heap;
	private Map _map;
	
	/**
	Create a new `PriorityMap`.
	
	Params:
		pairingHeapAllocator = An allocator used to allocate memory for the internal `PairingHeap`.
		map = An empty, unique (i.e. not referenced elsewhere), fresly created hash map instance.
	*/
	static if(is(HashMap == void)){
		this()(auto ref PairingHeapAllocator pairingHeapAllocator){
			this._heap = Heap(pairingHeapAllocator);
			this._map = null;
		}
	}else{
		this()(auto ref PairingHeapAllocator pairingHeapAllocator, auto ref Map map){
			this._heap = Heap(pairingHeapAllocator);
			this._map = map;
		}
	}
	
	this(scope ref PriorityMap rhs){
		this.tupleof[] = rhs.tupleof[];
		rhs._map = Map.init;
	}
	
	pragma(inline,true){
		@property const(Heap)* heap() const nothrow @nogc pure @safe => &_heap;
		@property const(Map)* map() const nothrow @nogc pure @safe => &_map;
		
		///Returns: The number of elements in the structure.
		@property size_t length() const nothrow @nogc pure @safe{
			assert(_heap.length == _map.length, "`heap` and `map` have different lengths. Please file a bug report");
			return _heap.length;
		}
		
		///Returns: `true` if the structure is empty.
		@property bool empty() const nothrow @nogc pure @safe{
			assert(_heap.empty == (_map.length == 0), "`heap` and `map` have different lengths. Please file a bug report");
			return _heap.empty;
		}
		
		///Get the largest element according to `less`.
		@property inout(Pair) front() inout nothrow @nogc pure @safe =>
			_heap.front;
	}
	
	///Removes the largest element.
	void popFront() nothrow{
		auto frontValue = _heap.front;
		_map.remove(frontValue.key);
		_heap.popFront();
	}
	
	static if(is(typeof(HashMap.rehash())))
	void rehash(){
		_map.rehash();
	}
	
	static if(!is(Value == void)){
		/**
		Inserts `value` into the structure, which can later be indexed by `key`.
		
		Does nothing if `key` already existed.
		*/
		void insert()(auto ref Key key, auto ref Value value) nothrow{
			if(key !in _map)
				_map[key] = _heap.insert(Pair(key, value));
		}
		
		///Returns: a pointer to the value associated with `key`, or `null` if `key` does not exist.
		inout(Value)* opBinaryRight(string op: "in")(const auto ref Key key) inout nothrow @nogc pure @trusted{
			if(auto node = key in _map)
				return cast(inout(Value)*)&(*node).value.value;
			return null;
		}
		
		/**
		Returns: The value associated with `key`.
		Throws: `RangeError` if `key` does not exist.
		*/
		inout(Value) opIndex()(const auto ref Key key) inout nothrow @nogc pure @safe =>
			_map[key].value.value;
		
		/**
		Sets the value associated with `key` to `value`.
		
		If `key` didn't exist already, `value` is newly inserted into the structure.
		*/
		Value opIndexAssign()(Value value, auto ref Key key) nothrow{
			if(auto node = key in _map){
				_heap.modify(*node, Pair(key, value));
			}else{
				_map[key] = _heap.insert(Pair(key, value));
			}
			return value;
		}
	}else{
		///Insert `key` into the structure.
		void insert()(auto ref Key key) nothrow{
			if(key !in _map)
				_map[key] = _heap.insert(Pair(key));
		}
		
		///Returns: `true` if `key` exists.
		bool opBinaryRight(string op: "in")(const auto ref Key key) inout nothrow @nogc pure @safe =>
			(key in _map) !is null;
	}
	
	/**
	Removes the value associated with `key` from the structure.
	
	Returns: `true` if `key` existed and was removed, or `false` if `key` did not exist.
	*/
	bool remove()(const auto ref Key key){
		if(auto node = key in _map){
			_heap.remove(*node);
			_map.remove(key);
			return true;
		}
		return false;
	}
}
