const std = @import("std");
const zglob = @import("glob.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Create a zGlob instance
    var glob = zglob.zGlob.init(allocator);

    // Get current directory using the fs field of zGlob
    const cwd = try glob.fs.getCwd();
    defer allocator.free(cwd);

    std.debug.print("Current working directory: {s}\n", .{cwd});

    // Test file existence using the fs field
    const build_zig_exists = glob.fs.fileExists("build.zig");
    std.debug.print("build.zig exists: {}\n", .{build_zig_exists});

    // Test if path is directory using the fs field
    const src_is_dir = glob.fs.isDirectory("src");
    std.debug.print("src is a directory: {}\n", .{src_is_dir});

    // Try using the glob function
    std.debug.print("\nSearching for *.zig files...\n", .{});
    const results = try glob.glob("*.zig");
    defer {
        for (results) |path| {
            allocator.free(path);
        }
        allocator.free(results);
    }

    for (results) |path| {
        std.debug.print("Found: {s}\n", .{path});
    }

    // Try a more complex pattern
    std.debug.print("\nSearching for src/*.zig files...\n", .{});
    const src_results = try glob.glob("src/*.zig");
    defer {
        for (src_results) |path| {
            allocator.free(path);
        }
        allocator.free(src_results);
    }

    for (src_results) |path| {
        std.debug.print("Found: {s}\n", .{path});
    }
}
