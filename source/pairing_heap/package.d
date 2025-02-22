/+
+               Copyright 2025 Aya Partridge
+ Distributed under the Boost Software License, Version 1.0.
+     (See accompanying file LICENSE_1_0.txt or copy at
+           http://www.boost.org/LICENSE_1_0.txt)
+/
module pairing_heap;

import std.algorithm.mutation, std.functional;
import memterface.allocator.gc, memterface.ctor, memterface.iface;

/**
A pairing heap (AKA priority queue) implementation.

If `less` is `"a < b"` (the default), then `PairingHeap` defines a max-heap, where `front` returns
the *largest* element. For a min-heap (where `front` returns the *smallest* element), the `less`
predicate should be set to `"a > b"`.

`Allocator` allows you to specify a custom allocator to use. By default, the garbage collector is used.
However, since nodes are manually freed, pointers to `Node`s returned from `insert`  will become dangling
pointers after they are extracted (via `popFront`) or `remove`d from the heap.
*/
struct PairingHeap(Element, alias less="a < b", Allocator=GCAllocator)
if(isAllocator!Allocator){
	alias Elem = Element;
	struct Node{
		private Elem _value;
		private Node* _firstChild; ///The node's first child.
		private Node* _prevSibling, _nextSibling; ///The siblings before and after this node in the doubly-linked list.
		
		pragma(inline,true){
			@property const(Elem)* value() const nothrow @nogc pure @safe => &_value;
			@property inout(Node)* firstChild() inout nothrow @nogc pure @safe => _firstChild;
			@property inout(Node)* prevSibling() inout nothrow @nogc pure @safe => _prevSibling;
			@property inout(Node)* nextSibling() inout nothrow @nogc pure @safe => _nextSibling;
		}
		
		private Node* merge(Node* rhs) nothrow @nogc pure @safe{
			//if either of the root nodes are `null`, return the opposite one
			if(&this is null){
				return rhs;
			}else if(rhs is null){
				return &this;
			}
			/* To maintain the max-heap invariant, make the node
			with the higher value the parent of the other node: */
			Node* parent=&this, child=rhs;
			if(binaryFun!less(this._value, rhs._value))
				swap(parent, child);
			
			child._nextSibling = parent._firstChild;
			if(parent._firstChild !is null)
				parent._firstChild._prevSibling = child;
			
			child._prevSibling = parent;
			parent._firstChild = child;
			
			parent._nextSibling = parent._prevSibling = null;
			
			return parent;
		}
		
		private Node* twoPassMerge() nothrow @nogc pure @safe{
			if(&this !is null){
				Node* tail;
				Node* next = &this;
				while(next !is null){
					Node* a = next;
					if(Node* b = next._nextSibling){
						next = b._nextSibling;
						auto result = a.merge(b);
						result._prevSibling = tail;
						tail = result;
					}else{
						a._prevSibling = tail;
						tail = a;
						break;
					}
				}
				
				Node* ret;
				while(tail !is null){
					next = tail._prevSibling;
					ret = ret.merge(tail);
					tail = next;
				}
				return ret;
			}else{
				return null;
			}
		}
	}
	private Allocator allocator;
	private Node* root;
	private size_t size;
	
	this()(auto ref Allocator allocator){
		this.allocator = allocator;
	}
	
	this(scope ref PairingHeap rhs) nothrow @nogc pure @safe{
		this.tupleof[] = rhs.tupleof[];
		rhs.root = null;
		rhs.size = 0;
	}
	
	pragma(inline,true){
		@property size_t length() const nothrow @nogc pure @safe =>
			size;
		
		@property bool empty() const nothrow @nogc pure @safe{
			assert((root is null) == (size == 0), "`PairingHeap` is empty but `length` is not `0`. Please file a bug report");
			return root is null;
		}
		
		@property inout(Elem) front() inout nothrow @nogc pure @safe
		in(root !is null) =>
			root._value;
		
		@property inout(Node)* frontNode() inout nothrow @nogc pure @safe =>
			root;
	}
	
	void popFront() nothrow
	in(root !is null){
		auto oldRoot = root;
		root = oldRoot._firstChild.twoPassMerge();
		allocator.dispose(oldRoot);
		size--;
	}
	
	Node* insert(Elem value) nothrow{
		auto newNode = allocator.constructNew!Node(value);
		root = root.merge(newNode);
		size++;
		return newNode;
	}
	
	private void removeImpl(Node* node) nothrow @nogc pure @safe
	in(node !is null){
		if(node !is root){
			auto _prevSibling = node._prevSibling;
			if(node is node._prevSibling._firstChild)
				node._prevSibling._firstChild = node._nextSibling;
			else
				node._prevSibling._nextSibling = node._nextSibling;
			
			if(node._nextSibling !is null)
				node._nextSibling._prevSibling = node._prevSibling;
			
			root = root.merge(node._firstChild.twoPassMerge());
		}else{
			root = node._firstChild.twoPassMerge();
		}
	}
	
	void remove(Node* node) nothrow
	in(node !is null){
		removeImpl(node);
		allocator.dispose(node);
		size--;
	}
	
	void modify(Node* node, Elem value) nothrow @nogc pure @safe
	in(node !is null){
		const newValueIsLess = binaryFun!less(value, node._value);
		node._value = value;
		if(newValueIsLess){
			removeImpl(node);
			node._firstChild = null;
			root = root.merge(node);
		}else if(node !is root){
			if(node is node._prevSibling._firstChild)
				node._prevSibling._firstChild = node._nextSibling;
			else
				node._prevSibling._nextSibling = node._nextSibling;
			
			if(node._nextSibling !is null)
				node._nextSibling._prevSibling = node._prevSibling;
			
			root = root.merge(node);
		}
	}
}

unittest{
	import std.algorithm, std.array, std.datetime.stopwatch, std.format, std.random, std.stdio;
	
	alias Heap = PairingHeap!int;
	
	foreach(iter; 0..16){
		Heap heap;
		Heap.Elem[] correctList;
		Heap.Node*[] nodes;
		
		foreach(_; 0..4){
			const n = uniform(-1_600, 1_600);
			
			nodes ~= heap.insert(n);
			correctList ~= n;
		}
		foreach(_; 0..60){
			std.random.choice([
				(){ //insert
					const n = uniform(-1_600, 1_600);
					
					nodes ~= heap.insert(n);
					correctList ~= n;
				}, (){ //remove
					if(nodes.length){
						const i = uniform(0U, nodes.length);
						auto nodeVal = *nodes[i].value;
						
						auto f = correctList.findSplit([nodeVal]);
						correctList = f[0] ~ f[2];
						heap.remove(nodes[i]);
						nodes = nodes[0..i] ~ nodes[i+1..$];
					}
				}, (){ //modify
					if(nodes.length){
						const i = uniform(0U, nodes.length);
						auto nodeVal = *nodes[i].value;
						
						const n = uniform(-1_600, 1_600);
						auto f = correctList.findSplit([nodeVal]);
						correctList = f[0] ~ n ~ f[2];
						heap.modify(nodes[i], n);
					}
				},
			])();
		}
		Heap.Elem[] heapList;
		foreach(item; heap){
			heapList ~= item;
		}
		assert(heap.empty, "Original heap not empty after being copied!");
		
		correctList = correctList.sort!"a > b".array;
		assert(heapList == correctList, format!"%s should be %s"(heapList, correctList));
	}
	
	void benchmarkFn(){
		Heap heap;
		Heap.Node*[] nodes;
		
		foreach(_; 0..200){
			std.random.choice([
				(){ //insert
					const n = uniform(-1_600, 1_600);
					nodes ~= heap.insert(n);
				}, (){ //remove
					if(nodes.length){
						const i = uniform(0U, nodes.length);
						auto nodeVal = nodes[i].value;
						
						heap.remove(nodes[i]);
						nodes = nodes[0..i] ~ nodes[i+1..$];
					}
				}, (){ //modify
					if(nodes.length){
						const i = uniform(0U, nodes.length);
						auto nodeVal = nodes[i].value;
						
						const n = uniform(-1_600, 1_600);
						heap.modify(nodes[i], n);
					}
				}, (){ //front/popFront
					if(!heap.empty){
						auto node = heap.frontNode;
						heap.popFront();
						
						auto nodesSplit = nodes.findSplit([node]);
						nodes = nodesSplit[0] ~ nodesSplit[2];
					}
				},
			])();
		}
	}
	enum runCount = 10_000;
	writefln!"Benchmark 1 took avg. %s"(benchmark!(() => benchmarkFn())(runCount)[0] / runCount);
}
