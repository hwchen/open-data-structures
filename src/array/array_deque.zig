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

        pub fn init(allocator: *Allocator) Self {
            // returns a pointer to an empty slice, so no allocation
            return Self{ .allocator = allocator, .backing_slice = &[_]T{}, .head = 0, .len = 0 };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.backing_slice);
        }

        fn idx(self: Self, i: usize) usize {
            return @mod(self.head + i, self.backing_slice.len);
        }

        pub fn get(self: Self, i: usize) ?T {
            return self.backing_slice[self.idx(i)];
        }

        pub fn set(self: Self, i: usize, x: T) ?T {
            const idx = self.idx(i);
            const res = self.backing_slice[idx];
            self.backing_slice[idx] = x;
            return res;
        }

        pub fn add(self: *Self, i: usize, x: T) !void {
            // resize if there's not enough slots in backing slice
            if (self.backing_slice.len == self.len) {
                try self.resize();
            }

            const idx = self.idx(i);

            self.backing_slice[insert_idx] = x;

            self.len += 1;
        }

        pub fn remove(self: *Self, i: usize) !?T {
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
