const std = @import("std");
const utf8 = @import("utf8.zig");
const zut = @import("zut.zig");

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
    dumpIndent(v, 2, 0);
}

fn dumpInt(comptime T: type, v: T) void {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    const hexpad = std.fmt.comptimePrint("{d}", .{@min(@sizeOf(T) * 2, 4)});
    print(ansi("{}", "38;5;194") ++ " [" ++ ansi("0x{X:0>" ++ hexpad ++ "}", "38;5;192") ++ "]", .{ v, @as(U, @bitCast(v)) });
}

pub fn dumpIndent(v: anytype, indent: usize, total_indent: usize) void {
    const T = @TypeOf(v);

    const VT = if (T == type) v else T;
    const has_size = VT != comptime_int and VT != comptime_float;
    print(ansi("{} ", "3;38;5;110"), .{VT});
    if (has_size) {
        print(ansi("{}B", "4;3;38;5;122"), .{@sizeOf(VT)});
        print(ansi("/{} ", "3;38;5;248"), .{@alignOf(VT)});
    }

    defer print("\n", .{});

    if (zut.isString(T)) {
        print(ansi("{s}", "38;5;214"), .{v});
        return;
    }

    switch (@typeInfo(T)) {
        .@"struct" => {
            dumpStructIndent(v, indent, total_indent + indent);
        },
        .pointer => |p| if (p.size != .slice) {
            print(ansi("*{0*}", "1;38;5;147"), .{v});
        } else {
            dumpArrayIndent(v, indent, total_indent + indent);
        },
        .array => dumpArrayIndent(v, indent, total_indent + indent),
        .@"union" => |u| {
            const tag_name = @tagName(v);
            inline for (u.fields) |field| {
                if (std.mem.eql(u8, tag_name, field.name)) {
                    dumpIndent(@field(v, field.name), indent, total_indent + indent);
                    break;
                }
            }
        },
        .int => dumpInt(T, v),
        .comptime_int => dumpInt(i64, v),
        .float => print(ansi("{d:.4}", "38;5;194"), .{v}),
        .comptime_float => print(ansi("{d:.4}", "38;5;194"), .{v}),
        .optional => if (v != null) dumpIndent(v.?, indent, total_indent + indent) else print(ansi("null", "38;5;250"), .{}),
        .@"enum" => print(ansi("{}", "38;5;122"), .{v}),
        .bool => {
            if (v) {
                print(ansi("{}", "38;5;118"), .{v});
            } else {
                print(ansi("{}", "38;5;202"), .{v});
            }
        },
        .type => if (@typeInfo(v) == .@"struct") dumpStructIndent(v, indent, total_indent + indent),
        else => print(ansi("[{}]{any}", "38;5;245"), .{ T, v }),
    }
}

fn pad(indent: usize) []const u8 {
    return SPACES[0..@min(indent, MAX_SPACES)];
}

fn dumpArray(data: anytype) void {
    dumpArrayIndent(data, 2, 0);
}

fn dumpArrayIndent(data: anytype, indent: usize, total_indent: usize) void {
    print("[\n", .{});

    const len: usize = if (data.len <= 10) data.len else @min(data.len, 5);
    for (0..len) |i| {
        print("{s}" ++ ansi("{}: ", "1"), .{ pad(total_indent), i });
        dumpIndent(data[i], indent, total_indent + indent);
    }

    if (data.len > 10) {
        print("\n{s}" ++ ansi("...{} more item/s\n\n", "1"), .{ pad(total_indent), data.len - 10 });
        for (data.len - 5..data.len) |i| {
            print("{s}" ++ ansi("{}: ", "1"), .{ pad(total_indent), i });
            dumpIndent(data[i], indent, total_indent);
        }
    }

    print("{s}]", .{pad(total_indent -| indent)});
}

fn dumpStruct(data: anytype) void {
    dumpStructIndent(data, 2, 0);
}

fn dumpStructIndent(data: anytype, indent: usize, total_indent: usize) void {
    const T = @TypeOf(data);
    const is_type = T == type;
    const VT = if (is_type) data else T;
    const fields = @typeInfo(VT).@"struct".fields;

    print("{{\n", .{});
    inline for (fields) |field| {
        const v = if (is_type) @FieldType(data, field.name) else @field(data, field.name);
        print("{s}" ++ ansi(">{}|", "38;5;245") ++ ansi("{s}: ", "1"), .{
            pad(total_indent),
            if (field.is_comptime) 0 else @offsetOf(VT, field.name),
            field.name,
        });
        dumpIndent(v, indent, total_indent);
    }
    print("{s}}}", .{pad(total_indent -| indent)});
}
