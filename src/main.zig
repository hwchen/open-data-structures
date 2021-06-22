pub const ArrayStack = @import("./array/array_stack.zig").ArrayStack;
pub const ArrayQueue = @import("./array/array_queue.zig").ArrayQueue;

test "all" {
    _ = @import("./array/array_stack.zig");
    _ = @import("./array/array_queue.zig");
}
