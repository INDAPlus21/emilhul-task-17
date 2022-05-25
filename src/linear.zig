// NOTE Not my code
// Example provided used as a working refernece for tests.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const LinearAllocator = struct {
    underlying: std.mem.Allocator,
    buffer: []u8,
    current_index: usize,

    pub fn init(underlying: std.mem.Allocator, size: usize) !LinearAllocator {
        return LinearAllocator{
            .underlying = underlying,
            .buffer = try underlying.alloc(u8, size),
            .current_index = 0,
        };
    }

    pub fn deinit(self: LinearAllocator) void {
        self.underlying.free(self.buffer);
    }

    pub fn allocator(self: *LinearAllocator) Allocator {
        return Allocator.init(self, alloc, resize, free);
    }

    fn alloc(
        self: *LinearAllocator,
        size: usize,
        ptr_align: u29,
        len_align: u29,
        ret_addr: usize,
    ) error{OutOfMemory}![]u8 {
        _ = len_align;

        // The return address is not needed, it can be used when detecting memory leaks (See GeneralPurposeAllocator)
        _ = ret_addr;

        // Align ptr to required pointer alignment
        const aligned_ptr = std.mem.alignForward(@ptrToInt(self.buffer.ptr) + self.current_index, ptr_align);

        // Calculate the index in the buffer of the aligned pointer
        const aligned_index = aligned_ptr - @ptrToInt(self.buffer.ptr);

        // Calculate the end index of the allocation
        const end_index = aligned_index + size;

        // If the end index is past the end of the allocator buffer return an OutOfMemory error
        if (end_index >= self.buffer.len) return error.OutOfMemory;

        // Create a slice of the allocator buffer for the allocation
        const allocation = self.buffer[aligned_index..end_index];

        // Set the current index to the end of the allocation buffer
        self.current_index = end_index;

        return allocation;
    }

    fn resize(
        self: *LinearAllocator,
        buf: []u8,
        buf_align: u29,
        new_size: usize,
        len_align: u29,
        ret_addr: usize,
    ) ?usize {
        _ = self;
        _ = buf_align;
        _ = ret_addr;

        // We can't grow any allocation because we might grow into another one
        if (new_size > buf.len) return null;

        // But we can shrink the allocation easily
        return std.mem.alignAllocLen(buf.len, new_size, len_align);
    }

    // The linear allocator can't free memory
    fn free(
        self: *LinearAllocator,
        buf: []u8,
        buf_align: u29,
        ret_addr: usize,
    ) void {
        _ = self;
        _ = buf_align;
        _ = ret_addr;
        _ = buf;
    }
};

test "linear allocator test" {
    var a = try LinearAllocator.init(std.heap.page_allocator, 800);
    defer a.deinit();
    const all = a.allocator();
    var arr = try all.alloc(u8, 20);
    assert(arr.len == 20);
    var arr2 = try all.alloc(u8, 2);
    assert(arr2.len == 2);
    arr = all.resize(arr, 4).?;
    assert(arr.len == 4);
    
    arr[0] = 'T';
    arr[1] = 'E';
    arr[2] = 'S';
    arr[3] = 'T';

    arr2[0] = 'O';
    arr2[1] = 'K';

    std.debug.print("{s} = {s}\n", .{arr, arr2});
}