const std = @import("std");
const utf8 = @import("utf8.zig");
const SliceChild = @import("zut.zig").SliceChild;

pub fn usage(name: []const u8, comptime options: anytype) void {
    const fmt_options = comptime ret: {
        var len = 0;
        const Step = enum { calc_len, build_str };

        for ([2]Step{ .calc_len, .build_str }) |step| {
            var i = 0;
            var p = 0;
            var r: [len:0]u8 = undefined;

            while (i + 1 < options.len) : (i += 2) {
                const s = "  {2s}{5s}" ++ options[i] ++ "{1s}\t{4s}" ++ options[i + 1] ++ "\n";
                switch (step) {
                    .calc_len => len += s.len,
                    .build_str => {
                        @memcpy(r[p .. p + s.len], s);
                        p += s.len;
                    },
                }
            }

            if (step == .build_str) {
                break :ret r;
            }
        }
    };

    std.debug.print(
        "{2s}{3s}Usage:{1s} {6s}{0s}\n" ++ fmt_options ++ "{1s}\n",
        .{ name, utf8.esc("0"), utf8.esc("1"), utf8.clr("220"), utf8.clr("195"), utf8.clr("225"), utf8.clr("156") },
    );
}

pub fn rtAssert(assertion: bool, err: anyerror) !void {
    if (!assertion) {
        return err;
    }
}

pub fn rtAssertFmt(assertion: bool, comptime f: []const u8, args: anytype) !void {
    if (!assertion) {
        errMsg(f, args);
        return error.AssertionFail;
    }
}

pub const stdout = std.io.getStdOut().writer();
pub const stderr = std.io.getStdErr().writer();
pub fn print(comptime f: []const u8, args: anytype) void {
    stdout.print(utf8.clr("230") ++ utf8.esc("1") ++ f ++ utf8.esc("0") ++ "\n", args) catch unreachable;
}

pub fn stdErrLn(comptime f: []const u8, args: anytype) void {
    stderr.print(utf8.clr("230") ++ utf8.esc("1") ++ f ++ utf8.esc("0") ++ "\n", args) catch unreachable;
}

pub fn warn(comptime f: []const u8, args: anytype) void {
    stderr.print(
        utf8.clr("220") ++ utf8.esc("1") ++ "Warning: " ++ utf8.esc("0") ++ utf8.clr("229") ++ f ++ utf8.esc("0") ++ "\n",
        args,
    ) catch unreachable;
}

pub fn errMsg(comptime f: []const u8, args: anytype) void {
    stderr.print(
        utf8.clr("210") ++ utf8.esc("1") ++ "Error: " ++ utf8.esc("0") ++ utf8.clr("217") ++ f ++ utf8.esc("0") ++ "\n",
        args,
    ) catch unreachable;
}

pub fn dump(v: anytype) void {
    dumpIndent(v, 2);
}

pub fn dumpIndent(v: anytype, comptime indent: usize) void {
    const T = @TypeOf(v);
    std.debug.print("[>{}:{}]", .{ @alignOf(T), @sizeOf(T) });
    switch (@typeInfo(T)) {
        .@"struct" => {
            dumpStructIndent(v, indent);
        },
        .pointer => |p| if (p.size != .Slice) {
            std.debug.print(utf8.esc("1") ++ utf8.clr("147") ++ "*{0*}" ++ utf8.esc("0"), .{v});
        } else {
            dumpArrayIndent(v, indent);
        },
        .array => dumpArrayIndent(v, indent),
        .@"union" => |u| {
            const tag_name = @tagName(v);
            inline for (u.fields) |field| {
                if (std.mem.eql(u8, tag_name, field.name)) {
                    dumpIndent(@field(v, field.name), indent + 2);
                    break;
                }
            }
        },
        .int => std.debug.print(intFmt(T), .{v}),
        .float => std.debug.print(utf8.clr("194") ++ "{d:.4}" ++ utf8.esc("0"), .{v}),
        .optional => if (v != null) dumpIndent(v.?, indent + 2) else std.debug.print(utf8.clr("250") ++ "null" ++ utf8.esc("0"), .{}),
        else => if (T == bool) {
            if (v) {
                std.debug.print(utf8.clr("118") ++ "{}" ++ utf8.esc("0"), .{v});
            } else {
                std.debug.print(utf8.clr("202") ++ "{}" ++ utf8.esc("0"), .{v});
            }
        } else std.debug.print(utf8.clr("245") ++ "[{s}]{any}" ++ utf8.esc("0"), .{ @typeName(T), v }),
    }
    std.debug.print("\n", .{});
}

pub fn dumpArray(data: anytype) void {
    dumpArrayIndent(data, 2);
}

pub fn dumpArrayIndent(data: anytype, comptime indent: usize) void {
    const T = @TypeOf(data);
    const name = @typeName(T);

    const C = SliceChild(T).?;
    const child_info = @typeInfo(C);

    if (child_info == .int and child_info.int.bits == 8 and std.unicode.utf8ValidateSlice(data[0..])) {
        std.debug.print(utf8.clr("214") ++ "{s}" ++ utf8.esc("0"), .{data});
        return;
    }

    if (@typeInfo(T) == .pointer) {
        std.debug.print(utf8.esc("1") ++ utf8.clr("211") ++ "[{}{s}[\n" ++ utf8.esc("0"), .{ data.len, name[1..] });
    } else {
        std.debug.print(utf8.esc("1") ++ utf8.clr("122") ++ "{s}[\n" ++ utf8.esc("0"), .{name});
    }

    const len: usize = if (data.len <= 10) data.len else @min(data.len, 5);
    for (0..len) |i| {
        std.debug.print(" " ** indent ++ utf8.esc("1") ++ "{}: " ++ utf8.esc("0"), .{i});
        dumpIndent(data[i], indent + 2);
    }

    if (data.len > 10) {
        std.debug.print("\n" ++ " " ** indent ++ utf8.esc("1") ++ "...{} more item/s\n\n" ++ utf8.esc("0"), .{data.len -| 10});
        for (data.len - 5..data.len) |i| {
            std.debug.print(" " ** indent ++ utf8.esc("1") ++ "{}: " ++ utf8.esc("0"), .{i});
            dumpIndent(data[i], indent + 2);
        }
    }

    std.debug.print(" " ** (indent -| 2) ++ "]", .{});
}

pub fn intFmt(comptime T: type) []const u8 {
    const hexpad = std.fmt.comptimePrint("{d}", .{@min(@sizeOf(T) * 2, 4)});
    return utf8.clr("194") ++ "{0}" ++ utf8.esc("0") ++ " [" ++ utf8.clr("192") ++ "0x{0X:0>" ++ hexpad ++ "}" ++ utf8.esc("0") ++ "]";
}

pub fn dumpStruct(data: anytype) void {
    dumpStructIndent(data, 2);
}

fn dumpStructIndent(data: anytype, comptime indent: usize) void {
    const T = @TypeOf(data);
    const fields = @typeInfo(T).@"struct".fields;

    std.debug.print(utf8.esc("1") ++ utf8.clr("122") ++ "{s}\n" ++ utf8.esc("0"), .{@typeName(T)});
    inline for (fields) |field| {
        const v = @field(data, field.name);
        std.debug.print(" " ** indent ++ utf8.clr("225") ++ "{s}: " ++ utf8.esc("0"), .{field.name});
        dumpIndent(v, indent + 2);
    }
}
