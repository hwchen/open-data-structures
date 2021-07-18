pub const ArrayStack = @import("./array/array_stack.zig").ArrayStack;
pub const ArrayQueue = @import("./array/array_queue.zig").ArrayQueue;
pub const ArrayDeque = @import("./array/array_deque.zig").ArrayDeque;

test "all" {
    _ = @import("./array/array_stack.zig");
    _ = @import("./array/array_queue.zig");
    _ = @import("./array/array_deque.zig");
}
