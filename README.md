# Pairing Heaps for D

[Official git repository](https://git.sleeping.town/ichordev/pairing-heap)

A [pairing heap](https://en.wikipedia.org/wiki/Pairing_heap) (AKA priority queue) implementation.

Pairing heaps have better time complexity than binary heaps (such as the one found in [std.container.binaryheap](https://dlang.org/phobos/std_container_binaryheap.html)) but without the poor real-world performance of Fibonacci heaps, while also allowing you to keep track of individual items inside of the heap. The module `priority_map` provides `PriorityMap`, which utilises the ability to track heap nodes by allowing you to store/query values with by key, and also query the minimum/maximum element stored in the structure.

Pairing heaps allocate a separate pointer for each node, so this implementation allows for a custom allocator to be used in order to reduce memory fragmentation. However, most operations in a pairing heap are O(1).

| Function name | Time complexity |
|---------------|-----------------|
| `front`       | *O*(1)          |
| `popFront`    | *O*(log *n*) [am.](https://en.wikipedia.org/wiki/Amortized_analysis)|
| `insert`      | *O*(1)          |
| `remove`      | *O*(1), or O(log *n*) [am.](https://en.wikipedia.org/wiki/Amortized_analysis) when called on root node|
| `modify`      | *O*(1) to increase an element, O(log *n*) [am.](https://en.wikipedia.org/wiki/Amortized_analysis) to decrease an element (for a max-heap)|

The interface is very similar to [std.container.binaryheap](https://dlang.org/phobos/std_container_binaryheap.html):
```d
import pairing_heap;
//a max-heap of `int`s using the GC allocator:
PairingHeap!int heap1;

//insert 100 elements:
while(heap1.length < 100)
	heap1.insert(std.random.uniform(0, 2_000);

//storing a pointer to an element for later:
auto node = heap1.insert(59);
heap1.modify(node, -100); //modify the element
heap1.remove(node); //remove the element
//NOTE: `node` is now an invalid pointer!

auto x = heap1.front; //get the 'largest' element
heap1.popFront(); //remove the 'largest' element

//a min-heap of `long`s with a custom allocator:
auto heap2 = PairingHeap!(long, "a > b", MyAllocator)(MyAllocator());
```

## Documentation

Inline documentation is available in the library's source code:

| Module               | Description |
|----------------------|-------------|
|[`pairing_heap`][heap]| The pairing heap implementation. |
|[`priority_map`][pmap]| A combination of a priority queue and a hash map. |

[heap]: https://git.sleeping.town/ichordev/pairing-heap/src/source/pairing_heap/package.d
[pmap]: https://git.sleeping.town/ichordev/pairing-heap/src/source/priority_map/package.d
