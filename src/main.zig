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
    } else {
        dbg.dump(try init.minimal.args.toSlice(init.arena.allocator()));
    }
}
