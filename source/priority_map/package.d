/+
+               Copyright 2025 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
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

Params:
	Key = The key to find elements by.
	Value = The value of each element. May be `void`.
	less = A binary function to compare elements with.
	PairingHeapAllocator = The allocator type used by the internal `PairingHeap`.
	HashMap = The type of hash map to use internally. Pass `void` to use D's built-in associative arrays.
		The hash map must support at least `.opIndex(Key)`, `.opIndexAssign(Value, Key)`, and `.opBinaryRight!"in"(Key)`.
		Its template parameters must start with `(Key, Value)`, with no non-optional parameters thereafter. If your hash map's
		template parameters don't meet this requirement then make an alias: `alias AliasedMap(Key,Value) = MyMap!(Value,Key,100)`
*/
struct PriorityMap(Key, Value, alias less="a.value < b.value", PairingHeapAllocator=GCAllocator, HashMap=void){
	struct KeyValue{
		Key key;
		static if(!is(Value == void))
		Value value;
	}
	alias Heap = PairingHeap!(KeyValue, less, PairingHeapAllocator);
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
		this(PairingHeapAllocator pairingHeapAllocator){
			this._heap = Heap(pairingHeapAllocator);
			this._map = null;
		}
	}else{
		this(PairingHeapAllocator pairingHeapAllocator, Map map){
			this._heap = Heap(pairingHeapAllocator);
			this._map = map;
		}
	}
	
	pragma(inline,true){
		@property const(Heap)* heap() const nothrow @nogc pure @safe => &_heap;
		@property const(Map)* map() const nothrow @nogc pure @safe => &_map;
		
		@property size_t length() const nothrow @nogc pure @safe{
			assert(_heap.length == _map.length, "`heap` and `map` have different lengths. Please file a bug report");
			return _heap.length;
		}
		
		@property bool empty() const nothrow @nogc pure @safe{
			assert(_heap.empty == (_map.length == 0), "`heap` and `map` have different lengths. Please file a bug report");
			return _heap.empty;
		}
		
		alias front = _heap.front;
	}
	
	void popFront() nothrow{
		auto frontValue = _heap.front;
		_map.remove(frontValue.key);
		_heap.popFront();
	}
	
	static if(is(typeof(HashMap.rehash)))
	void rehash(){
		_map.rehash;
	}
	
	static if(!is(Value == void)){
		void insert(const auto ref Key key, Value value) nothrow{
			if(key !in _map)
				_map[key] = _heap.insert(KeyValue(key, value));
		}
		
		inout(KeyValue)* opBinaryRight(string op: "in")(const auto ref Key key) inout nothrow @nogc pure @safe{
			if(auto node = key in _map)
				return &node.value.value;
			return null;
		}
		
		inout(KeyValue) opIndex(const auto ref Key key) inout nothrow @nogc pure @safe =>
			_map[key].value.value;
		
		Value opIndexAssign(Value value, const auto ref Key key) nothrow{
			if(auto node = key in _map){
				_heap.modify(*node, KeyValue(key, value));
			}else{
				_map[key] = _heap.insert(KeyValue(key, value));
			}
			return value;
		}
	}else{
		void insert(const auto ref Key key) nothrow{
			if(key !in _map)
				_map[key] = _heap.insert(KeyValue(key));
		}
		
		bool opBinaryRight(string op: "in")(const auto ref Key key) inout nothrow @nogc pure @safe =>
			(key in _map) !is null;
	}
	
	bool remove(const auto ref Key key){
		if(auto node = key in _map){
			_heap.remove(*node);
			_map.remove(key);
			return true;
		}
		return false;
	}
}
