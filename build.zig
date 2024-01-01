const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    b.installArtifact(b.dependency("tree-sitter", .{
        .target = target,
        .optimize = optimize,
    }).artifact("tree-sitter"));

    b.installArtifact(b.dependency("tree-sitter-html", .{
        .target = target,
        .optimize = optimize,
    }).artifact("tree-sitter-html"));

    b.installArtifact(b.dependency("tree-sitter-astro", .{
        .target = target,
        .optimize = optimize,
    }).artifact("tree-sitter-astro"));

    // const rust_build = b.addSystemCommand(&[_][]const u8{
    //     "cargo",
    //     "build",
    //     "--release",
    //     "--manifest-path",
    //     "swc/Cargo.toml",
    // });

    const exe = b.addExecutable(.{
        .name = "alpine-lsp",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const lsp_server = b.createModule(.{
        .source_file = .{ .path = "lsp_server/lsp_server.zig" },
    });
    const treez = b.dependency("treez", .{
        .target = target,
        .optimize = optimize,
    }).module("treez");

    exe.linkLibC();
    exe.linkLibCpp();

    exe.addModule("treez", treez);

    exe.linkLibrary(b.dependency("tree-sitter", .{
        .target = target,
        .optimize = optimize,
    }).artifact("tree-sitter"));

    exe.linkLibrary(b.dependency("tree-sitter-html", .{
        .target = target,
        .optimize = optimize,
    }).artifact("tree-sitter-html"));

    exe.linkLibrary(b.dependency("tree-sitter-astro", .{
        .target = target,
        .optimize = optimize,
    }).artifact("tree-sitter-astro"));

    exe.addModule("lsp_server", lsp_server);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
