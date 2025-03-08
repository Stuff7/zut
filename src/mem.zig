const std = @import("std");

pub fn intCast(I: type, i: anytype) I {
    return @as(I, @intCast(i));
}

pub fn floatCast(F: type, f: anytype) F {
    return @as(F, @floatCast(f));
}

pub fn asFloat(F: type, i: anytype) F {
    return @as(F, @floatFromInt(i));
}

pub fn memOffset(T: type, mem: *u8, offset: usize) *T {
    return @ptrFromInt(@intFromPtr(mem) + offset);
}

pub fn aligned(v: isize, alignment: isize) isize {
    return (v + (alignment - 1)) & ~(alignment - 1);
}

pub fn enumMask(flag: anytype, bitmask: anytype) bool {
    return mask(flag, @intFromEnum(bitmask));
}

pub fn mask(flag: anytype, bitmask: anytype) bool {
    return (flag & bitmask) == bitmask;
}

fn sliceContainsPtr(T: type, container: []const T, ptr: [*]const T) bool {
    return @intFromPtr(ptr) >= @intFromPtr(container.ptr) and
        @intFromPtr(ptr) < (@intFromPtr(container.ptr) + container.len * @sizeOf(T));
}

pub fn packedSize(s: type) usize {
    const fields = @typeInfo(s).@"struct".fields;
    var size = 0;

    inline for (fields) |field| {
        size += @sizeOf(@FieldType(s, field.name));
    }

    return size;
}

pub fn packedWrite(s: anytype, w: anytype) !void {
    const T = @TypeOf(s);
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        switch (@typeInfo(@FieldType(T, field.name))) {
            .array => _ = try w.write(std.mem.sliceAsBytes(&@field(s, field.name))),
            .pointer => |f| if (f.size == .Slice) {
                _ = try w.write(std.mem.sliceAsBytes(@field(s, field.name)));
            },
            else => _ = try w.write(std.mem.asBytes(&@field(s, field.name))),
        }
    }
}

pub fn packedRead(T: type, r: anytype, stop_field_name: ?[]const u8) !T {
    var self: T = undefined;
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        if (stop_field_name != null and std.mem.eql(u8, field.name, stop_field_name.?)) {
            break;
        }

        if (@typeInfo(@FieldType(T, field.name)) == .array) {
            _ = try r.read(std.mem.sliceAsBytes(&@field(self, field.name)));
        } else {
            _ = try r.read(std.mem.asBytes(&@field(self, field.name)));
        }
    }

    return self;
}
