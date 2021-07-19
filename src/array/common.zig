const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

// TODO implement rotate? Can I do that with memcpy?
pub fn resize_queue_backing(comptime T: type, head_ptr: *usize, len: usize, backing_slice_ptr: *[]T, allocator: *Allocator) !void {
    // fn params are immutable, so for when we want to set head and backing_slice, need to use pointers in the param.
    // When they're not being set, we can just set the value to a const in the fn scope.
    // If I set the value of the param ptr to a fn-local var, then it gets dropped when fn exits.
    // So you can't just do `var head = head_ptr.*` and `head = 0` and have that live beyond fn scope.
    const backing_slice = backing_slice_ptr.*;
    const head = head_ptr.*;

    if (backing_slice.len == 0) {
        backing_slice_ptr.* = try allocator.alloc(T, 1);
    } else if (len == 0) {
        allocator.free(backing_slice);
        backing_slice_ptr.* = &[_]T{};
    } else {
        const new_backing = try allocator.alloc(T, len * 2);

        if (head + len > backing_slice.len) {
            // there's a wraparound, both sizing up or down are possible

            const num_head_elem = backing_slice.len - head;

            // copy section from head to end of backing array
            mem.copy(T, new_backing, backing_slice[head..]);

            // copy section from beginning of backing slice to last element
            mem.copy(T, new_backing[num_head_elem..], backing_slice[0 .. len - num_head_elem]);
        } else {
            // no wraparound, sizing down or sizing up are possible

            //copy section from head to head + len
            mem.copy(T, new_backing, backing_slice[head .. head + len]);
        }

        allocator.free(backing_slice);
        backing_slice_ptr.* = new_backing;

        head_ptr.* = 0;
    }
}
