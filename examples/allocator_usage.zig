const std = @import("std");
const zglob = @import("zglob");

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();

    // Example 1: Using default page_allocator
    {
        const fs_helper = zglob.fs.Fs.init(std.heap.page_allocator);
        const cwd = try fs_helper.getCwd();
        defer std.heap.page_allocator.free(cwd); // Must free with page_allocator
        try stdout.print("Example 1 - Default allocator: Current directory: {s}\n", .{cwd});
    }

    // Example 2: Using arena allocator (best for short-lived programs)
    {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit(); // This frees ALL memory allocated by the arena

        const allocator = arena.allocator();
        const fs_helper = zglob.fs.Fs.init(allocator);
        const cwd = try fs_helper.getCwd();
        // No need to free cwd here - arena.deinit() will free everything at once

        try stdout.print("Example 2 - Arena allocator: Current directory: {s}\n", .{cwd});
    }

    // Example 3: Using a general purpose allocator (best for long-running programs)
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const fs_helper = zglob.fs.Fs.init(allocator);
        const cwd = try fs_helper.getCwd();
        defer allocator.free(cwd);

        try stdout.print("Example 3 - GPA: Current directory: {s}\n", .{cwd});
    }

    // Example 4: Using the zGlob struct with a GPA
    {
        try stdout.print("\nzGlob examples with different allocators:\n", .{});

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();

        // Create a zGlob instance with the GPA
        var glob = zglob.zGlob.init(allocator);

        // Use the glob function
        try stdout.print("Searching for *.zig files in the current directory...\n", .{});
        const results = try glob.glob("*.zig");
        defer {
            for (results) |path| {
                allocator.free(path);
            }
            allocator.free(results);
        }

        for (results) |path| {
            try stdout.print("Found: {s}\n", .{path});
        }
    }

    // Example 5: Using the zGlob struct with an arena allocator
    {
        try stdout.print("\nUsing zGlob with an arena allocator (no manual memory management needed):\n", .{});

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit(); // This will free ALL memory at once

        const allocator = arena.allocator();

        // Create a zGlob instance with the arena allocator
        var glob = zglob.zGlob.init(allocator);

        // Use the glob function
        try stdout.print("Searching for src/*.zig files...\n", .{});
        const results = try glob.glob("src/*.zig");
        // No need to free anything manually!

        for (results) |path| {
            try stdout.print("Found: {s}\n", .{path});
        }
    }
}
