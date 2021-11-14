const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const expectEqualSlices = std.testing.expectEqualSlices;

pub fn resize_queue_backing(comptime T: type, head_ptr: *usize, len: usize, backing_slice_ptr: *[]T, allocator: *Allocator) !void {
    // fn params are immutable, so for when we want to set head and backing_slice, need to use pointers in the param.
    // When they're not being set, we can just set the value to a const in the fn scope.
    // If I set the value of the param ptr to a fn-local var, then it gets dropped when fn exits.
    // So you can't just do `var head = head_ptr.*` and `head = 0` and have that live beyond fn scope.
    const backing_slice = backing_slice_ptr.*;
    const head = head_ptr.*;

    if (backing_slice.len == 0) {
        // Going from 0 items to 1
        backing_slice_ptr.* = try allocator.alloc(T, 1);
    } else if (len == 0) {
        // deallocate if backing slice is emptied
        allocator.free(backing_slice);
        backing_slice_ptr.* = &[_]T{};
    } else {
        // Going from at least one item, requires rotating

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

pub fn reserve_queue_backing(comptime T: type, len: usize, additional: usize, backing_slice_ptr: *[]T, allocator: *Allocator) !void {
    if (additional > backing_slice_ptr.*.len - len) {
        backing_slice_ptr.* = try allocator.realloc(backing_slice_ptr.*, len + additional);
    }
}

// start to end [..), shift left
pub fn shift_left(comptime T: type, start: usize, end: usize, slice: *[]T) void {
    if (start == end) {
        return;
    } else if (start < end) {
        // Only one slice to shift if start < end
        shift_left_contiguous(T, start, end, slice);
    } else {
        // Two slices to shift if start > end (wraparound)
        // Order matters, to make space for the wraparound shift
        shift_left_contiguous(T, start, slice.len, slice);
        shift_left_contiguous(T, 0, end, slice);
    }
}

// start to end [..), shift left.
// From start to end must be contiguous (start < end)
fn shift_left_contiguous(comptime T: type, start: usize, end: usize, slice_ptr: *[]T) void {
    std.debug.assert(start <= end);

    var slice = slice_ptr.*;

    const temp = slice[start];
    mem.copy(T, slice[start .. end - 1], slice[start + 1 .. end]);
    // shift start value one to the left
    // accounts for when start was slice[0]
    slice[@mod(start + slice.len - 1, slice.len)] = temp;
}

// start to end [..), shift right
pub fn shift_right(comptime T: type, start: usize, end: usize, slice: *[]T) void {
    if (start == end) {
        return;
    } else if (start < end) {
        // Only one slice to shift if start < end
        shift_right_contiguous(T, start, end, slice);
    } else {
        // Two slices to shift if start > end (wraparound)
        // Order matters, to make space for the wraparound shift
        shift_right_contiguous(T, 0, end, slice);
        shift_right_contiguous(T, start, slice.len, slice);
    }
}

// start to end [..), shift left.
// From start to end must be contiguous (start < end)
fn shift_right_contiguous(comptime T: type, start: usize, end: usize, slice_ptr: *[]T) void {
    std.debug.assert(start <= end);

    var slice = slice_ptr.*;

    const temp = slice[end - 1];
    // Order matters here, since it's copying in place index by index. Test with a right shift moving right side up.
    mem.copyBackwards(T, slice[start + 1 .. end], slice[start .. end - 1]);
    // shift end value one to the right
    // accounts for when end was tail
    slice[@mod(end, slice.len)] = temp;
}

// Testing:
// - shift left towards center
// - shift left away from center
// - shift left away from center wraparound
//
// Tested separately from shift_left because it's the underlying basis
test "shift_left_contiguous" {
    const alloc = std.testing.allocator;
    var input = std.ArrayList(u8).init(alloc);
    defer input.deinit();
    try input.append('0');
    try input.append('1');
    try input.append('2');
    try input.append('3');

    // towards center
    shift_left_contiguous(u8, 2, 4, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "0233");

    // away from center
    shift_left_contiguous(u8, 1, 3, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "2333");

    // wraparound
    shift_left_contiguous(u8, 0, 2, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "3332");
}

// Testing:
// - start == end
// - start > end
// - (start < end is already covered by shift_left_contiguous)
test "shift_left_non_contiguous" {
    const alloc = std.testing.allocator;
    var input = std.ArrayList(u8).init(alloc);
    defer input.deinit();
    try input.append('0');
    try input.append('1');
    try input.append('2');
    try input.append('3');

    // no shift
    shift_left(u8, 0, 0, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "0123");

    // start > end
    shift_left(u8, 3, 1, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "0130");
}

// Testing:
// - shift right towards center
// - shift right away from center
// - shift right away from center wraparound
//
// Tested separately from shift_right because it's the underlying basis
test "shift_right_contiguous" {
    const alloc = std.testing.allocator;
    var input = std.ArrayList(u8).init(alloc);
    defer input.deinit();
    try input.append('0');
    try input.append('1');
    try input.append('2');
    try input.append('3');

    // towards center
    shift_right_contiguous(u8, 0, 2, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "0013");

    // away from center
    shift_right_contiguous(u8, 1, 3, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "0001");

    // wraparound
    shift_right_contiguous(u8, 2, 4, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "1000");
}

// Testing:
// - start == end
// - start > end
// - (start < end is already covered by shift_left_contiguous)
test "shift_right_non_contiguous" {
    const alloc = std.testing.allocator;
    var input = std.ArrayList(u8).init(alloc);
    defer input.deinit();
    try input.append('0');
    try input.append('1');
    try input.append('2');
    try input.append('3');

    // no shift
    shift_right(u8, 0, 0, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "0123");

    // start > end
    shift_right(u8, 3, 1, &input.items);
    try expectEqualSlices(u8, input.items[0..4], "3023");
}

// TODO add more tests for resizing (it's kind of tested in tests for ArrayQueue already)
