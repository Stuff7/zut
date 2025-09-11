const std = @import("std");
const zut = @import("zut");

const utf8 = zut.utf8;
const dbg = zut.dbg;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        // zig fmt: off
        dbg.usage(args[0], .{
            "dbg  [options]",  "Run debug stuff",
            "utf8 [options]",  "Run utf8 stuff",
        });
        // zig fmt: on
        return;
    }

    if (std.mem.eql(u8, args[1], "dbg")) {
        if (args.len < 3) {
            // zig fmt: off
          dbg.usage(args[1], .{
            "log  <text>",  "Print a message",
            "warn <text>", "Print a warning",
            "err  <text>",  "Print an error",
          });
          // zig fmt: on
            return;
        }

        if (std.mem.eql(u8, args[2], "log")) {
            dbg.info("{s}", .{args[3]});
        } else if (std.mem.eql(u8, args[2], "warn")) {
            dbg.warn("{s}", .{args[3]});
        } else if (std.mem.eql(u8, args[2], "err")) {
            dbg.err("{s}", .{args[3]});
        }
    } else if (std.mem.eql(u8, args[1], "utf8")) {
        if (args.len < 3) {
            dbg.usage(args[1], .{ "<text>", "Sample text" });
            return;
        }

        dbg.info("Text: {s}\nLen: {d}\n", .{ args[2], try utf8.charLength(args[2]) });
    } else {
        dbg.dump(args);
        dbg.dump([_]u8{ 0, 1, 2, 3 });
    }
}
