const std = @import("std");

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
            .one => SliceChild(p.child),
            .slice => p.child,
            else => null,
        },
        else => null,
    };
}

pub inline fn isString(comptime T: type) bool {
    const info = @typeInfo(T);

    if (info == .pointer) {
        const ptr_info = info.pointer;

        // []const u8 or []u8 (slices)
        if (ptr_info.size == .slice) {
            return ptr_info.child == u8;
        }

        // *const [N]u8 or *[N]u8 (pointer to array)
        if (ptr_info.size == .one) {
            const child_info = @typeInfo(ptr_info.child);
            if (child_info == .array) {
                return child_info.array.child == u8;
            }
        }
    }

    if (info == .array) {
        return info.array.child == u8;
    }

    return false;
}

test isString {
    try std.testing.expect(isString([]const u8) == true);
    try std.testing.expect(isString([]u8) == true);
    try std.testing.expect(isString([10]u8) == true);
    try std.testing.expect(isString(*const [5]u8) == true);
    try std.testing.expect(isString(i32) == false);
    try std.testing.expect(isString([]i32) == false);
    try std.testing.expect(isString(comptime_int) == false);
    try std.testing.expect(isString(*const [5:0]u8) == true);
}
