const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const testing = std.testing;

const PoolNode = struct {
    next: ?*PoolNode,
    ptr: usize,
    id: usize,
};

pub const PoolAllocator = struct {
    underlying: Allocator,
    buf: []u8,
    buf_len: usize,
    chunk_size: usize,
    head: ?*PoolNode,

    pub fn init(underlying: Allocator, buf_len: usize, chunk_size: usize, chunk_align: u29) !PoolAllocator {
        const buf = try underlying.alloc(u8, buf_len);
        const initial_start = buf.ptr;
        const start = std.mem.alignForward(@ptrToInt(initial_start), chunk_align);
        var buf_length = buf_len; // Why can't I just make this mutable?
        buf_length -= start - @ptrToInt(initial_start);

        
        var chunk_size_align = std.mem.alignForward(chunk_size, chunk_align);
        assert(chunk_size >= @sizeOf(PoolNode));
        assert(buf_length >= chunk_size_align);

        const chunk_count = buf_length / chunk_size_align;
        var head: ?*PoolNode = null;
        var i: usize = 0;
        while (i < chunk_count) {
            const ptr = &buf[i*chunk_size_align];
            const node = @ptrCast(*PoolNode, @alignCast(@alignOf(PoolNode), ptr));
            
            node.* = PoolNode{
                .next = head,
                .ptr = @ptrToInt(ptr),
                .id = i,
            };

            head = &node;
            i += 1;
        }

        std.debug.print("Original Head {d}\n\n", .{head});

        return PoolAllocator{
            .underlying = underlying,
            .buf = buf,
            .buf_len = buf_length,
            .chunk_size = chunk_size_align,
            .head = head,
        };
    }

    pub fn deinit(self: PoolAllocator) void {
        self.underlying.free(self.buf);
    }

    pub fn allocator(self: *PoolAllocator) Allocator {
        return Allocator.init(self, alloc, resize, free);
    }

    fn alloc(
        self: *PoolAllocator,
        size: usize,
        ptr_align: u29,
        len_align: u29,
        ret_addr: usize,
    ) error{OutOfMemory}![]u8 {
        _ = len_align;
        _ = ret_addr;
        _ = ptr_align;

        assert(self.chunk_size == size);
        if (self.head == null) return error.OutOfMemory;

        const start_ptr = self.head.?.ptr;
        const start_index = start_ptr - @ptrToInt(self.buf.ptr);
        const end_index = start_index + self.chunk_size;
        const allocation = self.buf[start_index..end_index];

        self.head = self.head.?.next;

        std.debug.print("New Head {d}\n\n", .{self.head});
        return allocation;
    }

    fn resize(
        self: *PoolAllocator,
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
        self: *PoolAllocator,
        buf: []u8,
        buf_align: u29,
        ret_addr: usize,
    ) void {
        _ = buf_align;
        _ = ret_addr;

        const node_ptr = @ptrToInt(buf.ptr);

        const start_ptr = @ptrToInt(self.buf.ptr);
        const end_ptr = @ptrToInt(self.buf.ptr) + self.buf.len;

        if(!((start_ptr <= node_ptr) and (node_ptr < end_ptr))) {
            return;
        }

        var node = PoolNode{
             .next = self.head,
             .ptr = node_ptr,
             .id = 0,
        };
        
        std.debug.print("Old Head {d}\n\n", .{self.head});

        self.head = &node;

        std.debug.print("New Head {d}\n\n", .{self.head});
    }
};

test "pool allocator test" {
    const chunk_size = 40;
    var pool = try PoolAllocator.init(std.heap.page_allocator, 2000, chunk_size, 8);
    defer pool.deinit();
    const all = pool.allocator();
    assert(pool.head != null);
    const arr = try all.alloc(u8, chunk_size);
    assert(arr.len == chunk_size);
    all.free(arr);
    // Why does this cause a segmentation fault
    const arr2 = try all.alloc(u8, chunk_size);
    assert(arr2.len == chunk_size);

}