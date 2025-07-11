const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const fsPath = zglob.fs;

test "path normalization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Test basic path normalization
    const path1 = try fsPath.cleanPath(allocator, "a/b/c/../d");
    try testing.expectEqualStrings("a/b/d", path1);

    // Test with double dots going above root
    const path2 = try fsPath.cleanPath(allocator, "/a/b/../../c");
    try testing.expectEqualStrings("/c", path2);

    // Test with redundant slashes
    const path3 = try fsPath.cleanPath(allocator, "a///b//c");
    try testing.expectEqualStrings("a/b/c", path3);

    // Test with current directory references
    const path4 = try fsPath.cleanPath(allocator, "a/./b/./c");
    try testing.expectEqualStrings("a/b/c", path4);

    // Test absolute path
    const path5 = try fsPath.cleanPath(allocator, "/a/b/c");
    try testing.expectEqualStrings("/a/b/c", path5);

    // Test with base directory
    const path6 = try fsPath.normalizePath(allocator, "/base/dir", "a/b/c", .{});
    try testing.expectEqualStrings("/base/dir/a/b/c", path6);

    // Test with relative paths including parent references
    const path7 = try fsPath.normalizePath(allocator, "/base/dir", "../sibling", .{});
    try testing.expectEqualStrings("/base/sibling", path7);

    // Test empty path (returns ".")
    const path8 = try fsPath.cleanPath(allocator, "a/b/c/../../../");
    try testing.expectEqualStrings(".", path8);

    // Test path with only double dots
    const path9 = try fsPath.cleanPath(allocator, "..");
    try testing.expectEqualStrings("..", path9);
}
