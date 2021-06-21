const std = @import("std");
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
        items: []T,
        /// number of items actually stored
        /// size() in ODS
        len: usize,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            // returns a pointer to an empty slice, so no allocation
            return Self{ .allocator = allocator, .items = &[_]T{}, .len = 0 };
        }

        pub fn deinit() void {
            self.allocator.free(self.items);
        }

        pub fn get(self: Self, i: usize) ?T {
            return if (i < self.len) self.items[i] else null;
        }

        pub fn set(self: Self, i: usize, x: T) ?T {
            if (i >= self.len) {
                return null;
            }

            const res = self.items[i];
            self.items[i] = x;
            return res;
        }
    };
}

test "array stack" {
    const alloc = std.testing.allocator;
    var stack = ArrayStack(u8).init(alloc);

    std.testing.expectEqual(stack.len, 0);
    std.testing.expectEqual(stack.get(0), null);
    std.testing.expectEqual(stack.set(0, 0), null);
}
