const std = @import("std");

pub fn build(b: *std.Build) void {
    const NAME = "zut";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_module = b.addModule(NAME, .{ .root_source_file = b.path("src/zut.zig") });
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_module.addImport("zut", lib_module);

    const suffix = switch (optimize) {
        .Debug => "-dbg",
        .ReleaseFast => "",
        .ReleaseSafe => "-s",
        .ReleaseSmall => "-sm",
    };

    var name_buf: [NAME.len + 4]u8 = undefined;
    const bin_name = std.fmt.bufPrint(@constCast(&name_buf), "{s}{s}", .{ NAME, suffix }) catch unreachable;

    const exe = addBuild(b, main_module, bin_name, .exe);
    b.installArtifact(exe);

    const check = addBuild(b, main_module, bin_name, .exe);
    const check_step = b.step("check", "Build for LSP Diagnostics");
    check_step.dependOn(&check.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/utf8.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("zut", lib_module);
    const test_exe = addBuild(b, test_module, NAME ++ "-test", .tests);
    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
    check_step.dependOn(&test_exe.step);
}

fn addBuild(
    b: *std.Build,
    main_module: *std.Build.Module,
    bin_name: []const u8,
    kind: enum { tests, exe },
) *std.Build.Step.Compile {
    const exe = if (kind == .tests)
        b.addTest(.{ .name = bin_name, .root_module = main_module })
    else
        b.addExecutable(.{ .name = bin_name, .root_module = main_module });

    return exe;
}
