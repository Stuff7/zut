const std = @import("std");
const utf8 = @import("utf8.zig");
const zut = @import("zut.zig");
const ansi = utf8.ansi;

const Writer = std.Io.Writer;
const Type = std.builtin.Type;

const MAX_SPACES = 64;
const SPACES: [MAX_SPACES]u8 = @splat(' ');

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
    /// Set to negative for no limit
    max_array_items: isize = 10,

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
    const io = std.Options.debug_io;
    const prev = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(prev);
    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    writeDumpOpts(&stderr.file_writer.interface, v, opts) catch return;
}

pub fn writeDump(w: *Writer, v: anytype) Writer.Error!void {
    return writeDumpOpts(w, v, .{});
}

pub fn writeDumpOpts(w: *Writer, v: anytype, opts: DumpOptions) Writer.Error!void {
    const T = @TypeOf(v);

    const VT = if (T == type) v else T;
    const has_size = VT != comptime_int and VT != comptime_float;
    if (opts.shouldDumpType()) try w.print(ansi("{} ", "3;38;5;110"), .{VT});
    if (opts.shouldDumpSize() and has_size) {
        try w.print(ansi("{}B", "4;3;38;5;122"), .{@sizeOf(VT)});
        try w.print(ansi("/{} ", "3;38;5;248"), .{@alignOf(VT)});
    }

    defer w.print("\n", .{}) catch {};

    var o = opts;
    o.total_indent += o.indent;
    if (zut.mem.isByteSlice(T)) {
        if (std.unicode.utf8ValidateSlice(v)) {
            try w.print(ansi("\"{s}\"", "38;5;214"), .{v});
        } else {
            try w.print("{{\n", .{});
            try printHex(w, v, 8, o.total_indent);
            try w.print("{s}}}", .{pad(o.total_indent -| o.indent)});
        }
        return;
    }

    switch (@typeInfo(T)) {
        .@"struct" => try writeDumpStructOpts(w, v, o),
        .pointer => |p| if (p.size != .slice) try w.print(ansi("*{0*}", "1;38;5;147"), .{v}) else try writeDumpArrayOpts(w, v, o),
        .array => |a| if (matrixDim(a)) |dim| try writeDumpMatrix(w, dim, v, o) else try writeDumpArrayOpts(w, v, o),
        .@"union" => |u| try writeDumpUnionOpts(w, v, u, o),
        .int => try writeDumpInt(w, T, v, o.dump_int_hex),
        .comptime_int => try writeDumpInt(w, i64, v, o.dump_int_hex),
        .float => try w.print(ansi("{d:.4}", "38;5;194"), .{v}),
        .comptime_float => try w.print(ansi("{d:.4}", "38;5;194"), .{v}),
        .optional => try writeDumpOptionalOpts(w, v, o),
        .@"enum" => try w.print(ansi("{}", "38;5;122"), .{v}),
        .bool => if (v) try w.print(ansi("{}", "38;5;118"), .{v}) else try w.print(ansi("{}", "38;5;202"), .{v}),
        .type => if (@typeInfo(v) == .@"struct") try writeDumpStructOpts(w, v, o),
        else => try w.print(ansi("[{}]{any}", "38;5;245"), .{ T, v }),
    }
}

fn writeDumpOptionalOpts(w: *Writer, v: anytype, opts: DumpOptions) Writer.Error!void {
    if (v != null) {
        var o = opts;
        o.parsing_type = .suppress;
        try writeDumpOpts(w, v.?, o);
        o.parsing_type = opts.parsing_type;
        return;
    }
    try w.print(ansi("null", "38;5;250"), .{});
}

fn writeDumpUnionOpts(w: *Writer, v: anytype, u: Type.Union, opts: DumpOptions) Writer.Error!void {
    if (u.tag_type == null) {
        if (opts.shouldDumpType()) try w.print(ansi("union ", "3;38;5;216"), .{});
        try w.print("{{\n", .{});
        try printHex(w, std.mem.asBytes(&v), 8, opts.total_indent);
        try w.print("{s}}}", .{pad(opts.total_indent -| opts.indent)});
        return;
    }

    const tag_name = @tagName(v);
    inline for (u.field_names) |name| {
        if (std.mem.eql(u8, tag_name, name)) {
            if (opts.shouldDumpType()) try w.print(ansi(".{s} ", "3;38;5;153"), .{tag_name});
            try w.print("{{\n{s}", .{pad(opts.total_indent)});
            try writeDumpOpts(w, @field(v, name), opts);
            try w.print("{s}}}", .{pad(opts.total_indent -| opts.indent)});
            break;
        }
    }
}

fn writeDumpInt(w: *Writer, comptime T: type, v: T, dump_hex: bool) Writer.Error!void {
    const U = @Int(.unsigned, @bitSizeOf(T));
    const hexpad = std.fmt.comptimePrint("{d}", .{@min(@sizeOf(T) * 2, 4)});
    try w.print(ansi("{}", "38;5;194"), .{v});
    if (dump_hex) try w.print(" [" ++ ansi("0x{X:0>" ++ hexpad ++ "}", "38;5;192") ++ "]", .{@as(U, @bitCast(v))});
}

fn pad(indent: usize) []const u8 {
    return SPACES[0..@min(indent, MAX_SPACES)];
}

fn matrixDim(a: Type.Array) ?usize {
    if (std.meta.activeTag(@typeInfo(a.child)) != .float) return null;
    return switch (a.len) {
        4 => 2,
        9 => 3,
        16 => 4,
        else => null,
    };
}

fn writeDumpMatrix(w: *Writer, dim: usize, v: anytype, opts: DumpOptions) Writer.Error!void {
    const child = @typeInfo(@TypeOf(v)).array.child;
    if (comptime std.meta.activeTag(@typeInfo(child)) != .float) {
        try writeDumpArrayOpts(w, v, opts);
        return;
    }

    const N = @typeInfo(@TypeOf(v)).array.len;
    var widths: [4]usize = @splat(0);
    var lens: [N]usize = undefined;
    var buf: [N][32]u8 = undefined;
    for (0..dim) |row| {
        for (0..dim) |col| {
            const i = row * dim + col;
            const s = std.fmt.bufPrint(&buf[i], "{d:.2}", .{v[i]}) catch unreachable;
            lens[i] = s.len;
            widths[col] = @max(widths[col], s.len);
        }
    }

    try w.print("[\n", .{});
    for (0..dim) |row| {
        try w.print("{s}", .{pad(opts.total_indent)});
        for (0..dim) |col| {
            const i = row * dim + col;
            try w.print(ansi("{[s]s: >[w]}", "38;5;194") ++ "  ", .{ .s = buf[i][0..lens[i]], .w = widths[col] });
        }
        try w.print("\n", .{});
    }
    try w.print("{s}]", .{pad(opts.total_indent -| opts.indent)});
}

fn writeDumpArrayOpts(w: *Writer, data: anytype, opts: DumpOptions) Writer.Error!void {
    try w.print("[\n", .{});

    const max: usize = if (opts.max_array_items < 0) std.math.maxInt(usize) else @intCast(opts.max_array_items);
    const len: usize = if (data.len <= max) data.len else @min(data.len, max / 2);
    var o = opts;
    o.parsing_type = .array;
    for (0..len) |i| {
        try w.print("{s}" ++ ansi("{}: ", "1"), .{ pad(o.total_indent), i });
        try writeDumpOpts(w, data[i], o);
    }

    if (data.len > max) {
        try w.print("\n{s}" ++ ansi("...{} more item/s\n\n", "1"), .{ pad(o.total_indent), data.len - max });
        for (data.len - max / 2..data.len) |i| {
            try w.print("{s}" ++ ansi("{}: ", "1"), .{ pad(o.total_indent), i });
            try writeDumpOpts(w, data[i], o);
        }
    }
    o.parsing_type = opts.parsing_type;

    try w.print("{s}]", .{pad(o.total_indent -| o.indent)});
}

fn writeDumpStructOpts(w: *Writer, data: anytype, opts: DumpOptions) Writer.Error!void {
    const T = @TypeOf(data);
    const is_type = T == type;
    const VT = if (is_type) data else T;
    const type_info = @typeInfo(VT).@"struct";

    try w.print("{{\n", .{});
    var o = opts;
    o.parsing_type = .@"struct";
    inline for (type_info.field_names, type_info.field_attrs) |name, attr| {
        const v = if (is_type) @FieldType(data, name) else @field(data, name);
        try w.print("{s}", .{pad(o.total_indent)});
        if (o.dump_struct_field_offsets) {
            try w.print(ansi(">{}|", "38;5;245"), .{
                if (attr.@"comptime") 0 else @offsetOf(VT, name),
            });
        }
        try w.print(ansi("{s}: ", "1"), .{name});
        try writeDumpOpts(w, v, o);
    }
    o.parsing_type = opts.parsing_type;
    try w.print("{s}}}", .{pad(o.total_indent -| o.indent)});
}

pub fn printHex(w: *Writer, bytes: []const u8, max_rows: ?usize, left_pad: usize) Writer.Error!void {
    const row_size = 16;
    const total_rows = (bytes.len + row_size - 1) / row_size;
    const visible_rows = if (max_rows) |m| @min(m, total_rows) else total_rows;

    for (0..visible_rows) |row| {
        const start = row * row_size;
        const end = @min(start + row_size, bytes.len);
        const chunk = bytes[start..end];

        for (0..left_pad) |_| try w.print(" ", .{});

        // Offset
        try w.print("{x:0>8}" ++ ": ", .{start});

        // Hex bytes: pairs separated by spaces, gap in the middle
        for (0..row_size) |i| {
            if (i == 8) try w.print(" ", .{});
            if (i < chunk.len) {
                const byte = chunk[i];
                if (byte == 0x0a)
                    try w.print(ansi("{x:0>2}", "1;38;5;122"), .{byte})
                else if (byte == 0)
                    try w.print(ansi("{x:0>2}", "1"), .{byte})
                else if (byte < 32 or byte == 127)
                    try w.print(ansi("{x:0>2}", "1;38;5;220"), .{byte})
                else if (byte > 127)
                    try w.print(ansi("{x:0>2}", "1;38;5;210"), .{byte})
                else
                    try w.print(ansi("{x:0>2}", "1;38;5;156"), .{byte});
            } else {
                try w.print("  ", .{});
            }
            if (i % 2 == 1) try w.print(" ", .{});
        }

        try w.print(" ", .{});

        // ASCII
        for (chunk) |byte| {
            if (byte == 0x0a)
                try w.print(ansi(".", "1;38;5;122"), .{})
            else if (byte == 0)
                try w.print(ansi(".", "1"), .{})
            else if (byte < 32 or byte == 127)
                try w.print(ansi(".", "1;38;5;220"), .{})
            else if (byte > 127)
                try w.print(ansi(".", "1;38;5;210"), .{})
            else
                try w.print(ansi("{c}", "1;38;5;156"), .{byte});
        }

        try w.print("\n", .{});
    }

    if (max_rows) |m| {
        if (m < total_rows) {
            const omitted_bytes = bytes.len - m * row_size;
            for (0..left_pad) |_| try w.print(" ", .{});
            try w.print(ansi("  … {d} more bytes in {d} rows\n", "38;5;238"), .{
                omitted_bytes,
                total_rows - m,
            });
        }
    }
}
