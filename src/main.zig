const std = @import("std");
const zglob = @import("zglob");
const unicode = std.unicode;

const isWindows = @import("builtin").os.tag == .windows;

/// For debugging purposes
fn dumpPath(path: []const u8) void {
    std.debug.print("Path dump: ", .{});
    for (path) |c| {
        std.debug.print("{c}({d}) ", .{ c, c });
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stderr_buffer: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buffer);
    var stderr = std.fs.File.stderr().writer(&stderr_buffer);

    // Create a general purpose allocator as the parent
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Create an arena allocator with the gpa as its parent
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    // Get the allocator interface
    const allocator = arena.allocator();

    // Create a zGlob instance to use its filesystem functionality
    var glob = zglob.zGlob.init(allocator);

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    // Check command line mode
    const first_arg = args.next() orelse {
        try stderr.interface.writeAll("Usage:\n");
        try stderr.interface.writeAll("  zglob match <glob_pattern> <path>   - Test if a path matches a pattern\n");
        try stderr.interface.writeAll("  zglob find <glob_pattern> [path]    - Find files matching a pattern\n");
        return;
    };

    // Use the same glob instance that we created earlier
    const cwd = try glob.fs.getCwd();
    defer allocator.free(cwd);

    if (std.mem.eql(u8, first_arg, "match")) {
        // Match mode - test if a path matches a pattern
        const glob_pattern = args.next() orelse {
            try stderr.interface.writeAll("Usage: zglob match <glob_pattern> <path>\n");
            return;
        };

        const path = args.next() orelse {
            try stderr.interface.writeAll("Usage: zglob match <glob_pattern> <path>\n");
            return;
        };

        const result = zglob.globMatch(glob_pattern, path);

        try stdout.interface.print("Pattern: {s}\nPath: {s}\nResult: {}\n", .{ glob_pattern, path, result });

        if (result) {
            if (zglob.globMatchWithCaptures(glob_pattern, path, allocator)) |captures| {
                defer captures.deinit();

                try stdout.interface.print("Captures ({d}):\n", .{captures.items.len});
                for (captures.items, 0..) |capture, i| {
                    try stdout.interface.print("  {d}: {s}\n", .{ i, path[capture.start..capture.end] });
                }
            }
        }
    } else if (std.mem.eql(u8, first_arg, "find")) {
        // Find mode - find files matching a pattern
        const glob_pattern = args.next() orelse {
            try stderr.interface.writeAll("Usage: zglob find <glob_pattern> [path]\n");
            return;
        };

        const search_path = args.next() orelse cwd;

        // Handle relative paths correctly by using normalizePath with the CWD as base
        // For absolute paths, just use them directly
        const search_path_abs = if (glob.fs.isAbsolutePath(search_path))
            try allocator.dupe(u8, search_path)
        else
            try glob.fs.normalizePath(cwd, search_path, .{});
        defer allocator.free(search_path_abs);

        const matches = try glob.globWithCwd(glob_pattern, search_path_abs);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.interface.print("Found {d} matches:\n", .{matches.len});
        for (matches, 0..) |match_path, i| {
            try stdout.interface.print("{d}: {s}\n", .{ i + 1, match_path });
        }
    } else {
        try stderr.interface.writeAll("Unknown command. Use 'match' or 'find'.\n");
        try stderr.interface.writeAll("Usage:\n");
        try stderr.interface.writeAll("  zglob match <glob_pattern> <path>   - Test if a path matches a pattern\n");
        try stderr.interface.writeAll("  zglob find <glob_pattern> [path]    - Find files matching a pattern\n");
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
