# Zig Allocator by Emil Hultcrantz

Allocators in zig. Currently three versions:

* Linear which was provided as an example, not written by me. Used to compare results to.
* Arena. A similiar allocator to the linear only I've made it myself. Main difference is that you can make the latest allocation larger since it doesn't risk growing into any other chunks.
* Pool allocator works. Atleast for tests. Only slightly weird behaviour to beware about is that after freeing a poolNode the variable that was a pointer to it continues to point to the freed memory. Not sure if this is an issue but it's there.

## Run tests
* Clone repo
* Navigato to cloned repo directory
* In repo run zig test ./src/ <-file you want to run->.zig
* File names are:
    * linear.zig
    * arena.zig
    * pool.zig

