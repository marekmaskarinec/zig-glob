const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;

test "basic fs module functionality" {
    // Create an instance of Fs using testing allocator
    var fs = zglob.Fs.init(testing.allocator);

    // Get current directory using the Fs instance
    const cwd = try fs.getCwd();
    defer testing.allocator.free(cwd);

    try testing.expect(cwd.len > 0);

    // Try the build.zig file which we know exists
    const build_zig_path = "/home/pierre/project/javascript/bun-glob/port-rust-glob/zglob/build.zig";
    const exists = fs.fileExists(build_zig_path);
    try testing.expect(exists);
}

test "zGlob object-oriented approach" {
    // Create a zGlob instance
    var glob = zglob.zGlob.init(testing.allocator);

    // Use the fs field to access filesystem operations
    const cwd = try glob.fs.getCwd();
    defer testing.allocator.free(cwd);

    try testing.expect(cwd.len > 0);

    // Check if build.zig exists using the fs field
    const build_zig_path = "/home/pierre/project/javascript/bun-glob/port-rust-glob/zglob/build.zig";
    const exists = glob.fs.fileExists(build_zig_path);
    try testing.expect(exists);

    // Try a simple glob pattern to find zig files
    const zig_files = try glob.glob("*.zig");
    defer {
        for (zig_files) |file| {
            testing.allocator.free(file);
        }
        testing.allocator.free(zig_files);
    }

    // We should find at least one .zig file
    try testing.expect(zig_files.len > 0);
}

test "accessing fs through zGlob struct" {
    // Create an instance of zGlob with testing allocator
    var glob = zglob.zGlob.init(testing.allocator);

    // Access the fs functionality through the glob.fs field
    const cwd = try glob.fs.getCwd();
    defer testing.allocator.free(cwd);

    try testing.expect(cwd.len > 0);

    // Use other fs functionality
    const build_zig_path = "/home/pierre/project/javascript/bun-glob/port-rust-glob/zglob/build.zig";
    const exists = glob.fs.fileExists(build_zig_path);
    try testing.expect(exists);

    // The preferred way to use glob functionality is now:
    const results = try glob.glob("*.zig");
    defer {
        for (results) |path| {
            testing.allocator.free(path);
        }
        testing.allocator.free(results);
    }

    // Verify we found at least one .zig file (we know build.zig exists)
    try testing.expect(results.len > 0);
}
