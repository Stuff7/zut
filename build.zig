const std = @import("std");

pub fn build(b: *std.Build) void {
    const NAME = "zut";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_module = b.addModule(NAME, .{ .root_source_file = b.path("src/zut.zig"), .target = target });
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

    const exe = b.addExecutable(.{ .name = bin_name, .root_module = main_module });
    b.installArtifact(exe);

    const check = b.addExecutable(.{ .name = "check", .root_module = main_module });
    const check_step = b.step("check", "Build for LSP Diagnostics");
    check_step.dependOn(&check.step);

    const mod_tests = b.addTest(.{ .name = NAME, .root_module = lib_module });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    check_step.dependOn(&run_mod_tests.step);
}
