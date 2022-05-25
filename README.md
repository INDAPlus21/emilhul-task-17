# Zig Allocator by Emil Hultcrantz

Allocators in zig. Currently three versions:

* Linear which was provided as an example, not written by me. Used to compare results to.
* Arena. A similiar allocator to the linear only I've made it myself. Main difference is that you can make the latest allocation larger since it doesn't risk growing into any other chunks.
* Pool allocator that doesn't work. I think it kind of works in theory. The main issue seems to be with my initialization of the allocator. In the while loop it seems to update the first node and create pointers to itself instead of creating a new node each iteration as I'd expect.

## Run tests
* Clone repo
* Navigato to cloned repo directory
* In repo run zig test ./src/ <-file you want to run->.zig
* File names are:
    * linear.zig
    * arena.zig
    * pool.zig

