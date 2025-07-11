const std = @import("std");
const zglob = @import("zglob");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout = std.io.getStdOut().writer();

    // Basic pattern matching examples
    {
        try stdout.print("\n--- Basic pattern matching ---\n", .{});

        // Simple exact match
        try stdout.print("'file.txt' matches 'file.txt': {}\n", .{zglob.globMatch("file.txt", "file.txt")});

        // Wildcard matching
        try stdout.print("'*.txt' matches 'file.txt': {}\n", .{zglob.globMatch("*.txt", "file.txt")});
        try stdout.print("'file.*' matches 'file.txt': {}\n", .{zglob.globMatch("file.*", "file.txt")});
        try stdout.print("'*.md' matches 'file.txt': {}\n", .{zglob.globMatch("*.md", "file.txt")});

        // Question mark for single character
        try stdout.print("'file.???' matches 'file.txt': {}\n", .{zglob.globMatch("file.???", "file.txt")});
        try stdout.print("'file.???' matches 'file.md': {}\n", .{zglob.globMatch("file.???", "file.md")});

        // Character classes
        try stdout.print("'file.[tm]xt' matches 'file.txt': {}\n", .{zglob.globMatch("file.[tm]xt", "file.txt")});
        try stdout.print("'file.[tm]xt' matches 'file.mxt': {}\n", .{zglob.globMatch("file.[tm]xt", "file.mxt")});
        try stdout.print("'file.[tm]xt' matches 'file.dxt': {}\n", .{zglob.globMatch("file.[tm]xt", "file.dxt")});
    }

    // Path pattern matching
    {
        try stdout.print("\n--- Path pattern matching ---\n", .{});

        try stdout.print("'src/*.zig' matches 'src/glob.zig': {}\n", .{zglob.globMatch("src/*.zig", "src/glob.zig")});
        try stdout.print("'src/*.zig' matches 'src/fs/dir.zig': {}\n", .{zglob.globMatch("src/*.zig", "src/fs/dir.zig")});
        try stdout.print("'src/**/*.zig' matches 'src/fs/dir.zig': {}\n", .{zglob.globMatch("src/**/*.zig", "src/fs/dir.zig")});
        try stdout.print("'**/dir.zig' matches 'src/fs/dir.zig': {}\n", .{zglob.globMatch("**/dir.zig", "src/fs/dir.zig")});
    }

    // Brace expansion examples
    {
        try stdout.print("\n--- Brace expansion ---\n", .{});

        try stdout.print("'file.{txt,md}' matches 'file.txt': {}\n", .{zglob.globMatch("file.{txt,md}", "file.txt")});
        try stdout.print("'file.{txt,md}' matches 'file.md': {}\n", .{zglob.globMatch("file.{txt,md}", "file.md")});
        try stdout.print("'file.{txt,md}' matches 'file.js': {}\n", .{zglob.globMatch("file.{txt,md}", "file.js")});

        try stdout.print("'src/{fs,glob}/*.zig' matches 'src/fs/dir.zig': {}\n", .{zglob.globMatch("src/{fs,glob}/*.zig", "src/fs/dir.zig")});
    }

    // Pattern matching with captures
    {
        try stdout.print("\n--- Pattern matching with captures ---\n", .{});

        // Match with a capture for the extension
        const pattern = "file.*";
        const path = "file.txt";

        if (zglob.globMatchWithCaptures(pattern, path, allocator)) |captures| {
            defer captures.deinit();

            try stdout.print("'{s}' matches '{s}' with {d} captures:\n", .{ pattern, path, captures.items.len });

            for (captures.items, 0..) |capture, i| {
                try stdout.print("  Capture {d}: [{d}..{d}] = '{s}'\n", .{ i, capture.start, capture.end, path[capture.start..capture.end] });
            }
        } else {
            try stdout.print("'{s}' does not match '{s}' or has no captures\n", .{ pattern, path });
        }
    }
}
