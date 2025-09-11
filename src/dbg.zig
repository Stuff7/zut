const std = @import("std");
const utf8 = @import("utf8.zig");

const SliceChild = @import("zut.zig").SliceChild;

const ansi = utf8.ansi;
const print = std.debug.print;

const MAX_SPACES = 64;
const SPACES = [_]u8{' '} ** MAX_SPACES;

pub fn usage(name: []const u8, comptime options: anytype) void {
    const fmt_options = comptime ret: {
        var len = 0;
        const Step = enum { calc_len, build_str };

        for ([2]Step{ .calc_len, .build_str }) |step| {
            var i = 0;
            var p = 0;
            var r: [len:0]u8 = undefined;

            while (i + 1 < options.len) : (i += 2) {
                const s = ansi(options[i], "1;38;5;225") ++ "\t" ++ ansi(options[i + 1] ++ "\n", "38;5;195");
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

    std.debug.print(ansi("Usage:", "1;38;5;220") ++ ansi(" {s}\n" ++ fmt_options ++ "\n", "38;5;156"), .{name});
}

pub fn info(comptime f: []const u8, args: anytype) void {
    print(ansi(f, "1;38;5;230") ++ "\n", args);
}

pub fn warn(comptime f: []const u8, args: anytype) void {
    print(ansi("Warning: ", "1;38;5;220") ++ ansi(f ++ "\n", "38;5;229"), args);
}

pub fn err(comptime f: []const u8, args: anytype) void {
    print(ansi("Error: ", "1;38;5;210") ++ ansi(f ++ "\n", "38;5;217"), args);
}

pub fn dump(v: anytype) void {
    dumpIndent(v, 2);
}

pub fn dumpIndent(v: anytype, indent: usize) void {
    const T = @TypeOf(v);
    print("[>{}:{}]", .{ @alignOf(T), @sizeOf(T) });
    switch (@typeInfo(T)) {
        .@"struct" => {
            dumpStructIndent(v, indent);
        },
        .pointer => |p| if (p.size != .slice) {
            print(ansi("*{0*}", "1;38;5;147"), .{v});
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
        .int => print(intFmt(T), .{v}),
        .float => print(ansi("{d:.4}", "38;5;194"), .{v}),
        .optional => if (v != null) dumpIndent(v.?, indent + 2) else print(ansi("null", "38;5;250"), .{}),
        else => if (T == bool) {
            if (v) {
                print(ansi("{}", "38;5;118"), .{v});
            } else {
                print(ansi("{}", "38;5;202"), .{v});
            }
        } else print(ansi("[{s}]{any}", "38;5;245"), .{ @typeName(T), v }),
    }
    print("\n", .{});
}

fn pad(indent: usize) []const u8 {
    return SPACES[0..@min(indent, MAX_SPACES)];
}

fn dumpArray(data: anytype) void {
    dumpArrayIndent(data, 2);
}

fn dumpArrayIndent(data: anytype, indent: usize) void {
    const T = @TypeOf(data);
    const name = @typeName(T);

    const C = SliceChild(T).?;
    const child_info = @typeInfo(C);

    if (child_info == .int and child_info.int.bits == 8 and std.unicode.utf8ValidateSlice(data[0..])) {
        print(ansi("{s}", "38;5;214"), .{data});
        return;
    }

    if (@typeInfo(T) == .pointer) {
        print(ansi("[{}{s}[\n", "1;38;5;211"), .{ data.len, name[1..] });
    } else {
        print(ansi("{s}[\n", "1;38;5;122"), .{name});
    }

    const len: usize = if (data.len <= 10) data.len else @min(data.len, 5);
    for (0..len) |i| {
        print("{s}" ++ ansi("{}: ", "1"), .{ pad(indent), i });
        dumpIndent(data[i], indent + 2);
    }

    if (data.len > 10) {
        print("\n{s}" ++ ansi("...{} more item/s\n\n", "1"), .{ pad(indent), data.len - 10 });
        for (data.len - 5..data.len) |i| {
            print("{s}" ++ ansi("{}: ", "1"), .{ pad(indent), i });
            dumpIndent(data[i], indent + 2);
        }
    }

    print("{s}]", .{pad(indent - 2)});
}

fn intFmt(comptime T: type) []const u8 {
    const hexpad = std.fmt.comptimePrint("{d}", .{@min(@sizeOf(T) * 2, 4)});
    return ansi("{0}", "38;5;194") ++ " [" ++ ansi("0x{0X:0>" ++ hexpad ++ "}", "38;5;192") ++ "]";
}

fn dumpStruct(data: anytype) void {
    dumpStructIndent(data, 2);
}

fn dumpStructIndent(data: anytype, indent: usize) void {
    const T = @TypeOf(data);
    const fields = @typeInfo(T).@"struct".fields;

    print(ansi("{s}\n", "1;38;5;122"), .{@typeName(T)});
    inline for (fields) |field| {
        const v = @field(data, field.name);
        print("{s}" ++ ansi("{s}: ", "38;5;225"), .{ pad(indent), field.name });
        dumpIndent(v, indent + 2);
    }
}
