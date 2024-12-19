const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const hl2_exe = b.addExecutable(.{
        .name = "hl2-ace",
        .root_source_file = b.path("src/hl2-2707.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(hl2_exe);
    const run_hl2 = b.addRunArtifact(hl2_exe);
    run_hl2.step.dependOn(b.getInstallStep());
    const run_hl2_step = b.step("hl2", "Run hl2");
    run_hl2_step.dependOn(&run_hl2.step);

    const portal_exe = b.addExecutable(.{
        .name = "portal-ace",
        .root_source_file = b.path("src/portal-5135.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(portal_exe);
    const run_portal = b.addRunArtifact(portal_exe);
    run_portal.step.dependOn(b.getInstallStep());
    const run_portal_step = b.step("portal", "Run portal");
    run_portal_step.dependOn(&run_portal.step);
}
