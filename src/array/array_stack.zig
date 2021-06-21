const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;
const Allocator = mem.Allocator;

// Don't worry about alignment yet?
// Check https://github.com/ziglang/zig/blob/00982f75e92119aac6182ab9876adfb13305d1ed/lib/std/array_list.zig#L52 later
//
// Implements a List interface
pub fn ArrayStack(comptime T: type) type {
    return struct {
        allocator: *Allocator,
        /// backing array; capacity is size of the backing array
        backing_slice: []T,
        /// number of items actually stored
        /// size() in ODS
        len: usize,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            // returns a pointer to an empty slice, so no allocation
            return Self{ .allocator = allocator, .backing_slice = &[_]T{}, .len = 0 };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.backing_slice);
        }

        pub fn get(self: Self, i: usize) ?T {
            return if (i < self.len) self.backing_slice[i] else null;
        }

        pub fn set(self: Self, i: usize, x: T) ?T {
            if (i >= self.len) {
                return null;
            }

            const res = self.backing_slice[i];
            self.backing_slice[i] = x;
            return res;
        }

        pub fn add(self: *Self, i: usize, x: T) !void {
            // resize if there's not enough slots in backing slice
            if (self.backing_slice.len == self.len) {
                try self.resize();
            }

            if (i >= self.len) {
                // any i that's beyond len will be appended to end
                self.backing_slice[self.len] = x;
            } else {
                // shift elements after and including i to the right
                mem.copy(T, self.backing_slice[i + 1 ..], self.backing_slice[i..self.len]);

                // add item x at index i
                self.backing_slice[i] = x;
            }

            // update len
            self.len += 1;
        }

        pub fn remove(self: *Self, i: usize) !?T {
            if (i >= self.len) {
                return null;
            }

            // get the item at i
            const res = self.backing_slice[i];

            // shift elements
            mem.copy(T, self.backing_slice[i..], self.backing_slice[i + 1 .. self.len]);

            // update self.len
            self.len -= 1;

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
                // TODO start with larger allocation?
                self.backing_slice = try self.allocator.alloc(T, 1);
            } else {
                // why doesn't resize work? Ask in channel
                self.backing_slice = try self.allocator.realloc(self.backing_slice, self.len * 2);
            }
        }
    };
}

test "array stack basic get set" {
    const alloc = std.testing.allocator;
    var stack = ArrayStack(u8).init(alloc);
    defer stack.deinit();

    try expectEqual(stack.len, 0);
    try expectEqual(stack.get(0), null);
    try expectEqual(stack.set(0, 0), null);

    try stack.add(0, 1);

    try expectEqual(stack.len, 1);
    try expectEqual(stack.backing_slice.len, 1);
    try expectEqual(stack.get(0), 1);

    try expectEqual(stack.set(0, 2), 1);
    try expectEqual(stack.get(0), 2);
}

test "array stack example" {
    // Follows example from ODS book in figure 2.1
    const alloc = std.testing.allocator;
    var stack = ArrayStack(u8).init(alloc);
    defer stack.deinit();

    try stack.add(0, 'b');
    try stack.add(1, 'r');
    try stack.add(2, 'e');
    try stack.add(3, 'd');
    try stack.reserve(2);
    try expectEqual(stack.len, 4);
    try expectEqual(stack.backing_slice.len, 6);

    try stack.add(2, 'e');
    try stack.add(5, 'r');
    try expectEqual(stack.len, 6);

    try stack.add(5, 'e'); // resize
    try expectEqual(stack.len, 7);
    try expectEqual(stack.backing_slice.len, 12);

    _ = try stack.remove(4);
    _ = try stack.remove(4);
    try expectEqual(stack.len, 5);

    _ = try stack.remove(4); // resize
    try expectEqual(stack.len, 4);
    try expectEqual(stack.backing_slice.len, 8);

    _ = stack.set(2, 'i');
    try std.testing.expectEqual(stack.get(0).?, 'b');
    try std.testing.expectEqual(stack.get(1).?, 'r');
    try std.testing.expectEqual(stack.get(2).?, 'i');
    try std.testing.expectEqual(stack.get(3).?, 'e');
    try std.testing.expectEqual(stack.get(4), null);
}
