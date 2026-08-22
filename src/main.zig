const std = @import("std");
const zut = @import("zut");

const utf8 = zut.utf8;
const dbg = zut.dbg;

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();
    defer args.deinit();

    const program = args.next() orelse return error.ArgMissingProgram;
    const cmd = args.next() orelse {
        dbg.usage(program, .{
            "dbg  [options]", "Run debug stuff",
            "utf8 [options]", "Run utf8 stuff",
        });
        return;
    };

    if (std.mem.eql(u8, cmd, "dbg")) {
        const action = args.next() orelse {
            dbg.usage(cmd, .{
                "log  <text>", "Print a message",
                "warn <text>", "Print a warning",
                "err  <text>", "Print an error",
            });
            return;
        };

        if (std.mem.eql(u8, action, "log")) {
            dbg.info("{s}", .{args.next() orelse ""});
        } else if (std.mem.eql(u8, action, "warn")) {
            dbg.warn("{s}", .{args.next() orelse ""});
        } else if (std.mem.eql(u8, action, "err")) {
            dbg.err("{s}", .{args.next() orelse ""});
        }
    } else if (std.mem.eql(u8, cmd, "utf8")) {
        const action = args.next() orelse {
            dbg.usage(cmd, .{ "<text>", "Sample text" });
            return;
        };

        dbg.info("Text: {s}\nLen: {d}\n", .{ action, try utf8.charLength(action) });
    } else if (std.mem.eql(u8, cmd, "dump")) {
        const example = TestStruct{};
        dbg.info("=== Default Dump ===", .{});
        dbg.dump(example);
        dbg.info("=== Minimal Dump ===", .{});
        dbg.dumpOpts(example, .minimal);
        dbg.info("=== Verbose Dump ===", .{});
        dbg.dumpOpts(example, .verbose);
    } else {
        dbg.dump(try init.minimal.args.toSlice(init.arena.allocator()));
    }
}

const Status = enum {
    idle,
    running,
    failed,
};

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
};

const Item = struct {
    id: u32,
    name: []const u8,
    weight: f32,
};

// plain (untagged) union
const RawValue = union {
    i: i32,
    f: f32,
    b: bool,
};

// tagged union
const Payload = union(enum) {
    none,
    number: i64,
    text: []const u8,
    vec: Vec3,
};

pub const TestStruct = struct {
    id: u64 = 1,
    active: bool = true,
    score: f64 = 2.5,
    title: []const u8 = "Test title",
    description: ?[]const u8 = "Test description",
    status: Status = .running,
    values: [3]i32 = .{ 1, 2, 3 },
    tags: []const []const u8 = &[_][]const u8{
        "zig",
        "debug",
        "dump",
    },
    position: Vec3 = .{ .x = 1, .y = 2, .z = 3 },
    inventory: [2]Item = .{
        .{
            .id = 1,
            .name = "Sword",
            .weight = 3.5,
        },
        .{
            .id = 2,
            .name = "Shield",
            .weight = 5.0,
        },
    },
    raw: RawValue = .{ .i = 123 },
    payload: Payload = .{ .vec = .{ .x = 4, .y = 5, .z = 6 } },
    invalid_utf8: []const u8 = "\xff\xfe\x00bad",
    mat2: [4]f32 = .{
        1, 0,
        0, 1,
    },
    mat3: [9]f32 = .{
        1, 0, 0,
        0, 1, 0,
        0, 0, 1,
    },
    mat4: [16]f64 = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    },
};
