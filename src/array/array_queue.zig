const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const mem = std.mem;
const Allocator = mem.Allocator;

// Don't worry about alignment yet?
// Check https://github.com/ziglang/zig/blob/00982f75e92119aac6182ab9876adfb13305d1ed/lib/std/array_list.zig#L52 later
//
// Implements a Queue interface
pub fn ArrayQueue(comptime T: type) type {
    return struct {
        allocator: *Allocator,
        /// backing array; capacity is size of the backing array
        backing_slice: []T,
        /// index of the head element
        head: usize,
        /// number of items actually stored
        /// size() in ODS
        len: usize,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            // returns a pointer to an empty slice, so no allocation
            return Self{ .allocator = allocator, .backing_slice = &[_]T{}, .head = 0, .len = 0 };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.backing_slice);
        }

        pub fn add(self: *Self, x: T) !void {
            // resize if there's not enough slots in backing slice
            if (self.backing_slice.len == self.len) {
                try self.resize();
            }

            const insert_idx = @mod(self.head + self.len, self.backing_slice.len);

            self.backing_slice[insert_idx] = x;

            self.len += 1;
        }

        pub fn remove(self: *Self) !?T {
            // pop item at head
            const res = self.backing_slice[self.head];

            // update self.len and self.head
            self.len -= 1;
            self.head = @mod(self.head + 1, self.backing_slice.len);

            // resize if too much capacity
            if (self.backing_slice.len >= 3 * self.len) {
                try self.resize();
            }

            return res;
        }

        pub fn reserve(self: *Self, additional: usize) !void {
            if (additional > self.backing_slice.len - self.len) {
                self.backing_slice = try self.allocator.realloc(self.backing_slice, self.len + additional);
            }
        }

        fn resize(self: *Self) !void {
            if (self.backing_slice.len == 0) {
                self.backing_slice = try self.allocator.alloc(T, 1);
            } else if (self.len == 0) {
                self.allocator.free(self.backing_slice);
                self.backing_slice = &[_]T{};
            } else {
                const new_backing = try self.allocator.alloc(T, self.len * 2);

                if (self.head + self.len > self.backing_slice.len) {
                    // there's a wraparound, both sizing up or down are possible

                    const num_head_elem = self.backing_slice.len - self.head;

                    // copy section from head to end of backing array
                    mem.copy(T, new_backing, self.backing_slice[self.head..]);

                    // copy section from beginning of backing slice to last element
                    mem.copy(T, new_backing[num_head_elem..], self.backing_slice[0 .. self.len - num_head_elem]);
                } else {
                    // no wraparound, sizing down or sizing up are possible

                    //copy section from head to head + len
                    mem.copy(T, new_backing, self.backing_slice[self.head .. self.head + self.len]);
                }

                self.allocator.free(self.backing_slice);
                self.backing_slice = new_backing;

                self.head = 0;
            }
        }
    };
}

test "array queue basic" {
    const alloc = std.testing.allocator;
    var queue = ArrayQueue(u8).init(alloc);
    defer queue.deinit();

    try expectEqual(queue.len, 0);

    try queue.add(1);
    try expectEqual(queue.len, 1);
    try expectEqual(queue.backing_slice.len, 1);

    const res = try queue.remove();
    try expectEqual(res, 1);
}

test "array queue example" {
    // Follows example from ODS book in figure 2.2
    const alloc = std.testing.allocator;
    var queue = ArrayQueue(u8).init(alloc);
    defer queue.deinit();

    // To get to beginning example state
    try queue.reserve(6);
    try queue.add(0);
    try queue.add(0);
    try queue.add('a');
    try queue.add('b');
    try queue.add('c');
    _ = try queue.remove();
    _ = try queue.remove();
    try expectEqual(queue.head, 2);
    try expectEqual(queue.len, 3);
    try expectEqual(queue.backing_slice.len, 6);

    // now example
    try queue.add('d');
    try queue.add('e');
    _ = try queue.remove();
    try queue.add('f');
    try queue.add('g');
    try expectEqualSlices(u8, queue.backing_slice, "efgbcd");

    try queue.add('h'); // resize
    try expectEqualSlices(u8, queue.backing_slice[0..6], "bcdefg");
    try expectEqual(queue.head, 0);
    try expectEqual(queue.len, 7);

    const x = try queue.remove();
    try expectEqual(queue.head, 1);
    try expectEqual(queue.len, 6);
    try expectEqual(x, 'b');

    // go beyond example, to shrink
    _ = try queue.remove();
    _ = try queue.remove();
    try expectEqual(queue.backing_slice.len, 8);
}
