const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const mem = std.mem;
const Allocator = mem.Allocator;

const common = @import("./common.zig");

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
            return common.reserve_queue_backing(T, self.len, additional, &self.backing_slice, self.allocator);
        }

        fn resize(self: *Self) !void {
            return common.resize_queue_backing(T, &self.head, self.len, &self.backing_slice, self.allocator);
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
    // For resizing, tests:
    // - up with wraparound
    // - down with no wraparound

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
    try expectEqualSlices(u8, queue.backing_slice[0..7], "bcdefgh");
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
    try expectEqual(queue.len, 4);
    try expectEqualSlices(u8, queue.backing_slice[0..4], "efgh");
}

test "array queue: size up no wraparound" {
    const alloc = std.testing.allocator;
    var queue = ArrayQueue(u8).init(alloc);
    defer queue.deinit();

    try queue.add('a');
    try queue.add('b');
    try queue.add('c');
    try queue.add('d');
    try queue.add('e');
    try expectEqual(queue.head, 0);
    try expectEqual(queue.len, 5);
    try expectEqual(queue.backing_slice.len, 8);
}

test "array queue: size down with wraparound" {
    const alloc = std.testing.allocator;
    var queue = ArrayQueue(u8).init(alloc);
    defer queue.deinit();

    try queue.add('a');
    try queue.add('b');
    try queue.add('c');
    try queue.add('d');
    try queue.add('e');
    try queue.add('f');
    try queue.add('g');
    try queue.add('h');
    try expectEqual(queue.backing_slice.len, 8);
    _ = try queue.remove();
    _ = try queue.remove();
    _ = try queue.remove();
    _ = try queue.remove();
    try queue.add('x');

    // current state should be [x,_,_,_,e,f,g,h]

    _ = try queue.remove();
    _ = try queue.remove();
    _ = try queue.remove(); // trigger resize
    try expectEqual(queue.backing_slice.len, 4);
    try expectEqual(queue.len, 2);
    try expectEqualSlices(u8, queue.backing_slice[0..2], "hx");
}
