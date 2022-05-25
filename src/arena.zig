const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const ArenaAllocator = struct {
    underlying: std.mem.Allocator,
    buf: []u8,
    prev_offset: usize,
    curr_offset: usize,
    
    pub fn init(underlying: std.mem.Allocator, size: usize) !ArenaAllocator {
        return ArenaAllocator{
            .underlying = underlying,
            .buf = try underlying.alloc(u8, size),
            .prev_offset = 0,
            .curr_offset = 0,
        };
    }

    pub fn deinit(self: ArenaAllocator) void {
        self.underlying.free(self.buf);
    }

    pub fn allocator(self: *ArenaAllocator) Allocator {
        return Allocator.init(self, alloc, resize, free);
    }

    fn alloc(
        self: *ArenaAllocator,
        size: usize,
        ptr_align: u29,
        len_align: u29,
        ret_addr: usize,
    ) error{OutOfMemory}![]u8 {
        _ = len_align;
        _ = ret_addr;

        const curr_ptr = @ptrToInt(self.buf.ptr) + self.curr_offset;

        const aligned_offset = std.mem.alignForward(curr_ptr, ptr_align);

        const index_offset = aligned_offset - @ptrToInt(self.buf.ptr);

        if (!(index_offset+size <= self.buf.len)) return error.OutOfMemory;
    
        const allocation = self.buf[index_offset..index_offset+size];

        self.prev_offset = index_offset;
        self.curr_offset = index_offset + size;

        return allocation;
    }

    fn resize(
        self: *ArenaAllocator,
        buf: []u8,
        buf_align: u29,
        new_size: usize,
        len_align: u29,
        ret_addr: usize,
    ) ?usize {
        _ = buf_align;
        _ = ret_addr;
        
        const alloc_buf_ptr = @ptrToInt(self.buf.ptr);
        const curr_buf_ptr = @ptrToInt(buf.ptr);
        // Buffer is within allocators underlying buffer.
        if(alloc_buf_ptr <= curr_buf_ptr and curr_buf_ptr < alloc_buf_ptr + self.buf.len) {
            // Were trying to resize last buffer
            if(alloc_buf_ptr+self.prev_offset == curr_buf_ptr) {
                // Can safely grow as long as it's not larger than underlying buffer
                if(self.prev_offset + new_size > self.buf.len) return null;
                // Sett current offset to new
                self.curr_offset = self.prev_offset + new_size;
                if(new_size > buf.len) return new_size;
                return std.mem.alignAllocLen(buf.len, new_size, len_align);
            } else {
                // Not the last buffer means it can't safely grow
                if(new_size > buf.len) return null;
                // But we can shrink the allocation
                return std.mem.alignAllocLen(buf.len, new_size, len_align);
            }
        } else {
            // Buffer out of bounds for allocator
            return null;
        }
    }

    fn free(
        self: *ArenaAllocator,
        buf: []u8,
        buf_align: u29,
        ret_addr: usize,
    ) void {
        _ = self;
        _ = buf_align;
        _ = ret_addr;
        _ = buf;

        // Arena Allocator can't free only part of memory. Only here for completeness
    }
};

test "arena allocator test" {
    var a = try ArenaAllocator.init(std.heap.page_allocator, 800);
    defer a.deinit();
    const allocator = a.allocator();
    var arr = try allocator.alloc(u8, 20);
    assert(arr.len == 20);
    var arr2 = try allocator.alloc(u8, 1);
    assert(arr2.len == 1);
    // Latest allocation so can grow
    arr2 = allocator.resize(arr2, 2).?;
    assert(arr2.len == 2);
    // Not latest allocation can't grow
    try testing.expect(allocator.resize(arr, 21) == null);
    // But can shrink.
    arr = allocator.resize(arr, 4).?;
    assert(arr.len == 4);
    arr[0] = 'T';
    arr[1] = 'E';
    arr[2] = 'S';
    arr[3] = 'T';
    
    arr2[0] = 'O';
    arr2[1] = 'K';

    std.debug.print("{s} = {s}\n", .{arr, arr2});
}
