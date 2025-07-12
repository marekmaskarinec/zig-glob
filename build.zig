const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("zglob", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "zglob",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Add module unit tests
    const mod_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add glob-specific tests
    const glob_tests = b.addTest(.{
        .name = "glob-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/glob_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    // Add UTF-8 glob tests
    const glob_utf8_tests = b.addTest(.{
        .name = "glob-utf8-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/glob_utf8_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    // Add invalid UTF-8 glob tests
    const glob_invalid_utf8_tests = b.addTest(.{
        .name = "glob-invalid-utf8-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/glob_invalid_utf8_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    const fs_tests = b.addTest(.{
        .name = "fs-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/fs_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    const test_step = b.step("test", "Run all tests");
    const glob_safety_tests = b.addTest(.{
        .name = "glob-safety-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/glob_safety_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });
    const run_glob_safety_tests = b.addRunArtifact(glob_safety_tests);
    test_step.dependOn(&run_glob_safety_tests.step);

    const run_mod_tests = b.addRunArtifact(mod_unit_tests);
    test_step.dependOn(&run_mod_tests.step);

    const run_glob_tests = b.addRunArtifact(glob_tests);
    test_step.dependOn(&run_glob_tests.step);

    const run_glob_utf8_tests = b.addRunArtifact(glob_utf8_tests);
    test_step.dependOn(&run_glob_utf8_tests.step);

    const run_glob_invalid_utf8_tests = b.addRunArtifact(glob_invalid_utf8_tests);
    test_step.dependOn(&run_glob_invalid_utf8_tests.step); // Add glob finder tests
    const glob_finder_tests = b.addTest(.{
        .name = "glob-finder-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/glob_finder_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    const run_glob_finder_tests = b.addRunArtifact(glob_finder_tests);
    test_step.dependOn(&run_glob_finder_tests.step);

    // Add path tests
    const path_tests = b.addTest(.{
        .name = "path-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/path_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });
    const run_path_tests = b.addRunArtifact(path_tests);
    test_step.dependOn(&run_path_tests.step);

    const ext_bash_test = b.addTest(.{
        .name = "match-extbash",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/glob_extbash_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    const run_ext_bash_test = b.addRunArtifact(ext_bash_test);
    test_step.dependOn(&run_ext_bash_test.step);

    const run_fs_tests = b.addRunArtifact(fs_tests);
    test_step.dependOn(&run_fs_tests.step);

    // Allocator examples have been moved to examples directory
    // Global allocator tests have been removed

    // Add steps for specific test categories
    const utf8_test_step = b.step("test-utf8", "Run UTF-8 specific tests");
    const run_only_utf8_tests = b.addRunArtifact(glob_utf8_tests);
    utf8_test_step.dependOn(&run_only_utf8_tests.step);

    const ascii_test_step = b.step("test-ascii", "Run ASCII specific tests");
    const run_only_ascii_tests = b.addRunArtifact(glob_tests);
    ascii_test_step.dependOn(&run_only_ascii_tests.step);

    const invalid_utf8_test_step = b.step("test-invalid-utf8", "Run invalid UTF-8 specific tests");
    const run_only_invalid_utf8_tests = b.addRunArtifact(glob_invalid_utf8_tests);
    invalid_utf8_test_step.dependOn(&run_only_invalid_utf8_tests.step);

    const sanity_test = b.step("test-sanity", "Run sanity (extremely large input and the likes) specific tests");
    const run_only_sanity_test_tests = b.addRunArtifact(glob_invalid_utf8_tests);
    sanity_test.dependOn(&run_only_sanity_test_tests.step);

    const fs_test_step = b.step("test-fs", "Run filesystem module tests");
    const run_only_fs_tests = b.addRunArtifact(fs_tests);
    fs_test_step.dependOn(&run_only_fs_tests.step);

    // Create examples step for all examples
    const examples_step = b.step("examples", "Build and run examples");

    const allocator_test_step = b.step("test-allocator", "Run allocator usage examples (moved to examples)");
    allocator_test_step.dependOn(examples_step);

    // Global allocator tests have been removed

    // Add dedicated step for finder tests
    const finder_test_step = b.step("test-finder", "Run glob finder tests");
    const run_only_finder_tests = b.addRunArtifact(glob_finder_tests);
    finder_test_step.dependOn(&run_only_finder_tests.step);

    // Add dedicated step for extbash tests
    const extbash_test_step = b.step("test-extbash", "Run extended bash pattern matching tests");
    const run_only_extbash_tests = b.addRunArtifact(ext_bash_test);
    extbash_test_step.dependOn(&run_only_extbash_tests.step);

    // Allocator usage example
    const allocator_usage_exe = b.addExecutable(.{
        .name = "allocator-usage-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/allocator_usage.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zglob", .module = mod },
            },
        }),
    });

    b.installArtifact(allocator_usage_exe);

    const run_allocator_usage = b.addRunArtifact(allocator_usage_exe);
    const run_allocator_usage_step = b.step("run-allocator-example", "Run the allocator usage example");
    run_allocator_usage_step.dependOn(&run_allocator_usage.step);
    examples_step.dependOn(&run_allocator_usage.step);
}
