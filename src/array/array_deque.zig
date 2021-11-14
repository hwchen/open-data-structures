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
// Implements a List interface
pub fn ArrayDeque(comptime T: type) type {
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

        const Error = Allocator.Error | error.out_of_bounds;

        pub fn init(allocator: *Allocator) Self {
            // returns a pointer to an empty slice, so no allocation
            return Self{ .allocator = allocator, .backing_slice = &[_]T{}, .head = 0, .len = 0 };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.backing_slice);
        }

        /// For internal use, derives the index in the backing slice from the queue's index
        fn index(self: Self, i: usize) usize {
            return @mod(self.head + i, self.backing_slice.len);
        }

        /// For internal use, derives the tail index in the backing slice from the queue's index
        fn tail_index(self: Self) usize {
            return self.index(self.head + self.len);
        }

        pub fn get(self: Self, i: usize) ?T {
            return self.backing_slice[self.index(i)];
        }

        pub fn set(self: Self, i: usize, x: T) ?T {
            const idx = self.index(i);
            const res = self.backing_slice[idx];
            self.backing_slice[idx] = x;
            return res;
        }

        pub fn add(self: *Self, i: usize, x: T) !void {
            // check that it's within bounds. Can add to tail, but not beyond.
            if (i > self.len) {
                return error.out_of_bounds;
            }

            // resize if there's not enough slots in backing slice
            if (self.backing_slice.len == self.len) {
                try self.resize();
            }

            const insert_idx = self.index(i);

            // shift lower or upper to find room to insert
            if (i < self.len / 2) {
                // shift left
                // insert (insert index has shifted left now)
                // update head
                common.shift_left(T, self.head, insert_idx, &self.backing_slice);
                self.backing_slice[insert_idx - 1] = x;
                self.head = @mod(self.head + self.backing_slice.len - 1, self.backing_slice.len);
            } else {
                // shift right
                // insert
                common.shift_right(T, insert_idx, self.tail_index(), &self.backing_slice);
                self.backing_slice[insert_idx] = x;
            }

            // Insert

            self.len += 1;
        }

        pub fn add_tail(self: *Self, x: T) !void {
            return self.add(self.len, x);
        }

        pub fn remove(self: *Self, i: usize) !?T {
            const remove_idx = self.index(i);
            const res = self.backing_slice[remove_idx];

            if (i < self.len / 2) {
                // shift right side
                // update head
                common.shift_right(T, self.head, remove_idx, &self.backing_slice);
                self.head += 1;
            } else {
                common.shift_left(T, remove_idx, self.tail_index(), &self.backing_slice);
            }

            // resize if too much capacity
            if (self.backing_slice.len >= 3 * self.len) {
                try self.resize();
            }

            self.len -= 1;

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

test "array dequeue example" {
    // Follows example from ODS book in figure 2.3

    const alloc = std.testing.allocator;
    var queue = ArrayDeque(u8).init(alloc);
    defer queue.deinit();

    // To get to beginning example state
    try queue.reserve(12);
    try queue.add_tail('a');
    try queue.add_tail('b');
    try queue.add_tail('c');
    try queue.add_tail('d');
    try queue.add_tail('e');
    try queue.add_tail('f');
    try queue.add_tail('g');
    try queue.add_tail('h');
    try expectEqual(queue.head, 0);
    try expectEqual(queue.len, 8);
    try expectEqual(queue.backing_slice.len, 12);

    // now example
    _ = try queue.remove(2);
    try expectEqualSlices(u8, queue.backing_slice[1..8], "abdefgh");
    try queue.add(4, 'x');
    try expectEqualSlices(u8, queue.backing_slice[1..9], "abdexfgh");
    try queue.add(3, 'y');
    try expectEqual(queue.head, 0);
    try expectEqualSlices(u8, queue.backing_slice[0..9], "abdyexfgh");
    // Different from book, because book comparison is incorrect. They
    // do a float division comparison, when it should be an integer
    // comparison
    try queue.add(3, 'z');
    try expectEqual(queue.head, 11);
    try expectEqualSlices(u8, queue.backing_slice[0..9], "bdzyexfgh");
    try expectEqualSlices(u8, queue.backing_slice[11..], "a");
}
