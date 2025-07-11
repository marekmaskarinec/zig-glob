const std = @import("std");
const zglob = @import("zglob");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout = std.io.getStdOut().writer();

    // Simple pattern matching
    {
        try stdout.print("\n--- Simple pattern matching ---\n", .{});
        const pattern = "src/*.zig";
        try stdout.print("Finding files matching pattern: {s}\n", .{pattern});

        const matches = try zglob.glob(allocator, pattern);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches:\n", .{matches.len});
        for (matches) |match_path| {
            try stdout.print("  {s}\n", .{match_path});
        }
    }

    // Recursive pattern matching
    {
        try stdout.print("\n--- Recursive pattern matching ---\n", .{});
        const pattern = "**/*.zig";
        try stdout.print("Finding files matching pattern: {s}\n", .{pattern});

        const matches = try zglob.glob(allocator, pattern);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches (showing first 5):\n", .{matches.len});
        const limit = @min(matches.len, 5);
        for (matches[0..limit]) |match_path| {
            try stdout.print("  {s}\n", .{match_path});
        }
        if (matches.len > 5) {
            try stdout.print("  ... and {d} more files\n", .{matches.len - 5});
        }
    }

    // Using the struct API
    {
        try stdout.print("\n--- Using the struct API ---\n", .{});
        const pattern = "src/fs/*.zig";
        try stdout.print("Finding files matching pattern: {s}\n", .{pattern});

        const glob_finder = zglob.zGlob.init(allocator);
        const matches = try glob_finder.glob(pattern);
        defer {
            for (matches) |match_path| {
                allocator.free(match_path);
            }
            allocator.free(matches);
        }

        try stdout.print("Found {d} matches:\n", .{matches.len});
        for (matches) |match_path| {
            try stdout.print("  {s}\n", .{match_path});
        }
    }
}
