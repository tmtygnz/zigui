const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sokol_dependency = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const truetype_dependency = b.dependency("TrueType", .{
        .target = target,
        .optimize = optimize,
    });

    // Mods
    const mod = b.addModule("zigui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("sokol", sokol_dependency.module("sokol"));
    mod.addImport("TrueType", truetype_dependency.module("TrueType"));
    mod.addCSourceFile(.{
        .file = b.path("deps/libschrift/schrift.c"),
        .flags = &[_][]const u8{ "-std=c99", "-O3" },
    });
    mod.addIncludePath(b.path("deps/libschrift/"));

    // Executable
    const exe = b.addExecutable(.{
        .name = "zigui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addImport("zigui", mod);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
