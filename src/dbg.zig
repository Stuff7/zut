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

pub const DumpOptions = struct {
    indent: usize = 2,
    total_indent: usize = 0,
    parsing_type: enum {
        primitive,
        array,
        @"struct",
        suppress,
    } = .primitive,
    dump_types: bool = true,
    dump_array_elem_types: bool = false,
    dump_struct_field_types: bool = true,
    dump_sizes: bool = true,
    dump_array_elem_sizes: bool = false,
    dump_struct_field_sizes: bool = true,
    dump_struct_field_offsets: bool = true,
    dump_int_hex: bool = true,

    pub fn shouldDumpType(self: @This()) bool {
        return switch (self.parsing_type) {
            .primitive => self.dump_types,
            .array => self.dump_array_elem_types,
            .@"struct" => self.dump_struct_field_types,
            .suppress => false,
        };
    }

    pub fn shouldDumpSize(self: @This()) bool {
        return switch (self.parsing_type) {
            .primitive => self.dump_sizes,
            .array => self.dump_array_elem_sizes,
            .@"struct" => self.dump_struct_field_sizes,
            .suppress => false,
        };
    }

    pub const minimal = @This(){
        .dump_types = true,
        .dump_array_elem_types = false,
        .dump_struct_field_types = false,
        .dump_sizes = false,
        .dump_array_elem_sizes = false,
        .dump_struct_field_sizes = false,
        .dump_struct_field_offsets = false,
        .dump_int_hex = false,
    };

    pub const verbose = @This(){
        .dump_types = true,
        .dump_array_elem_types = true,
        .dump_struct_field_types = true,
        .dump_sizes = true,
        .dump_array_elem_sizes = true,
        .dump_struct_field_sizes = true,
        .dump_struct_field_offsets = true,
        .dump_int_hex = true,
    };
};

pub fn dump(v: anytype) void {
    dumpOpts(v, .{});
}

pub fn dumpOpts(v: anytype, opts: DumpOptions) void {
    const T = @TypeOf(v);

    const VT = if (T == type) v else T;
    const has_size = VT != comptime_int and VT != comptime_float;
    if (opts.shouldDumpType()) print(ansi("{} ", "3;38;5;110"), .{VT});
    if (opts.shouldDumpSize() and has_size) {
        print(ansi("{}B", "4;3;38;5;122"), .{@sizeOf(VT)});
        print(ansi("/{} ", "3;38;5;248"), .{@alignOf(VT)});
    }

    defer print("\n", .{});

    if (zut.isString(T)) {
        print(ansi("\"{s}\"", "38;5;214"), .{v});
        return;
    }

    var o = opts;
    o.total_indent += o.indent;
    switch (@typeInfo(T)) {
        .@"struct" => dumpStructOpts(v, o),
        .pointer => |p| if (p.size != .slice) print(ansi("*{0*}", "1;38;5;147"), .{v}) else dumpArrayOpts(v, o),
        .array => dumpArrayOpts(v, o),
        .@"union" => |u| dumpUnionOpts(v, u, o),
        .int => dumpInt(T, v, o.dump_int_hex),
        .comptime_int => dumpInt(i64, v, o.dump_int_hex),
        .float => print(ansi("{d:.4}", "38;5;194"), .{v}),
        .comptime_float => print(ansi("{d:.4}", "38;5;194"), .{v}),
        .optional => dumpOptionalOpts(v, o),
        .@"enum" => print(ansi("{}", "38;5;122"), .{v}),
        .bool => if (v) print(ansi("{}", "38;5;118"), .{v}) else print(ansi("{}", "38;5;202"), .{v}),
        .type => if (@typeInfo(v) == .@"struct") dumpStructOpts(v, o),
        else => print(ansi("[{}]{any}", "38;5;245"), .{ T, v }),
    }
}

fn dumpOptionalOpts(v: anytype, opts: DumpOptions) void {
    if (v != null) {
        var o = opts;
        o.parsing_type = .suppress;
        dumpOpts(v.?, o);
        o.parsing_type = opts.parsing_type;
        return;
    }
    print(ansi("null", "38;5;250"), .{});
}

fn dumpUnionOpts(v: anytype, u: std.builtin.Type.Union, opts: DumpOptions) void {
    if (u.tag_type == null) {
        print(ansi("|untagged union bytes| ", "38;5;210") ++ "{{\n", .{});
        printHex(std.mem.asBytes(&v), 8, opts.total_indent);
        print("{s}}}", .{pad(opts.total_indent -| opts.indent)});
        return;
    }

    const tag_name = @tagName(v);
    inline for (u.fields) |field| {
        if (std.mem.eql(u8, tag_name, field.name)) {
            print(ansi("|tagged union|.{s} ", "38;5;211") ++ "{{\n{s}", .{ tag_name, pad(opts.total_indent) });
            dumpOpts(@field(v, field.name), opts);
            print("{s}}}", .{pad(opts.total_indent -| opts.indent)});
            break;
        }
    }
}

fn dumpInt(comptime T: type, v: T, dump_hex: bool) void {
    const U = std.meta.Int(.unsigned, @bitSizeOf(T));
    const hexpad = std.fmt.comptimePrint("{d}", .{@min(@sizeOf(T) * 2, 4)});
    print(ansi("{}", "38;5;194"), .{v});
    if (dump_hex) print(" [" ++ ansi("0x{X:0>" ++ hexpad ++ "}", "38;5;192") ++ "]", .{@as(U, @bitCast(v))});
}

fn pad(indent: usize) []const u8 {
    return SPACES[0..@min(indent, MAX_SPACES)];
}

fn dumpArray(data: anytype) void {
    dumpArrayOpts(data, .{});
}

fn dumpArrayOpts(data: anytype, opts: DumpOptions) void {
    print("[\n", .{});

    const len: usize = if (data.len <= 10) data.len else @min(data.len, 5);
    var o = opts;
    o.parsing_type = .array;
    for (0..len) |i| {
        print("{s}" ++ ansi("{}: ", "1"), .{ pad(o.total_indent), i });
        dumpOpts(data[i], o);
    }

    if (data.len > 10) {
        print("\n{s}" ++ ansi("...{} more item/s\n\n", "1"), .{ pad(o.total_indent), data.len - 10 });
        for (data.len - 5..data.len) |i| {
            print("{s}" ++ ansi("{}: ", "1"), .{ pad(o.total_indent), i });
            dumpOpts(data[i], o);
        }
    }
    o.parsing_type = opts.parsing_type;

    print("{s}]", .{pad(o.total_indent -| o.indent)});
}

fn dumpStruct(data: anytype) void {
    dumpStructOpts(data, .{});
}

fn dumpStructOpts(data: anytype, opts: DumpOptions) void {
    const T = @TypeOf(data);
    const is_type = T == type;
    const VT = if (is_type) data else T;
    const fields = @typeInfo(VT).@"struct".fields;

    print("{{\n", .{});
    var o = opts;
    o.parsing_type = .@"struct";
    inline for (fields) |field| {
        const v = if (is_type) @FieldType(data, field.name) else @field(data, field.name);
        print("{s}", .{pad(o.total_indent)});
        if (o.dump_struct_field_offsets) {
            print(ansi(">{}|", "38;5;245"), .{
                if (field.is_comptime) 0 else @offsetOf(VT, field.name),
            });
        }
        print(ansi("{s}: ", "1"), .{field.name});
        dumpOpts(v, o);
    }
    o.parsing_type = opts.parsing_type;
    print("{s}}}", .{pad(o.total_indent -| o.indent)});
}

pub fn printHex(bytes: []const u8, max_rows: ?usize, left_pad: usize) void {
    const row_size = 16;
    const total_rows = (bytes.len + row_size - 1) / row_size;
    const visible_rows = if (max_rows) |m| @min(m, total_rows) else total_rows;

    for (0..visible_rows) |row| {
        const start = row * row_size;
        const end = @min(start + row_size, bytes.len);
        const chunk = bytes[start..end];

        for (0..left_pad) |_| print(" ", .{});

        // Offset
        print("{x:0>8}" ++ ": ", .{start});

        // Hex bytes: pairs separated by spaces, gap in the middle
        for (0..row_size) |i| {
            if (i == 8) print(" ", .{});
            if (i < chunk.len) {
                const byte = chunk[i];
                if (byte == 0x0a)
                    print(ansi("{x:0>2}", "1;38;5;122"), .{byte})
                else if (byte == 0)
                    print(ansi("{x:0>2}", "1"), .{byte})
                else if (byte < 32 or byte == 127)
                    print(ansi("{x:0>2}", "1;38;5;220"), .{byte})
                else if (byte > 127)
                    print(ansi("{x:0>2}", "1;38;5;210"), .{byte})
                else
                    print(ansi("{x:0>2}", "1;38;5;156"), .{byte});
            } else {
                print("  ", .{});
            }
            if (i % 2 == 1) print(" ", .{});
        }

        print(" ", .{});

        // ASCII
        for (chunk) |byte| {
            if (byte == 0x0a)
                print(ansi(".", "1;38;5;122"), .{})
            else if (byte == 0)
                print(ansi(".", "1"), .{})
            else if (byte < 32 or byte == 127)
                print(ansi(".", "1;38;5;220"), .{})
            else if (byte > 127)
                print(ansi(".", "1;38;5;210"), .{})
            else
                print(ansi("{c}", "1;38;5;156"), .{byte});
        }

        print("\n", .{});
    }

    if (max_rows) |m| {
        if (m < total_rows) {
            const omitted_bytes = bytes.len - m * row_size;
            for (0..left_pad) |_| print(" ", .{});
            print(ansi("  … {d} more bytes in {d} rows\n", "38;5;238"), .{
                omitted_bytes,
                total_rows - m,
            });
        }
    }
}
