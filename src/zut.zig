pub const utf8 = @import("utf8.zig");
pub const dbg = @import("dbg.zig");
pub const mem = @import("mem.zig");

pub fn FnErrorReturn(comptime t: anytype) type {
    return @typeInfo(@typeInfo(@TypeOf(t)).@"fn".return_type.?).error_union.error_set;
}

pub fn SliceChild(T: type) ?type {
    const info = @typeInfo(T);

    return switch (info) {
        .array => |a| a.child,
        .pointer => |p| switch (p.size) {
            .One => SliceChild(p.child),
            .Slice => p.child,
            else => null,
        },
        else => null,
    };
}
