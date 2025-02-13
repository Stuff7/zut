pub const utf8 = @import("utf8.zig");
pub const dbg = @import("dbg.zig");
pub const mem = @import("mem.zig");

pub fn FnErrorReturn(comptime t: anytype) type {
    return @typeInfo(@typeInfo(@TypeOf(t)).@"fn".return_type.?).error_union.error_set;
}
