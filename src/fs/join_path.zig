const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const path = @import("path.zig");

/// Join two paths together with proper handling of path separators
/// If second_path is absolute, it replaces first_path entirely
pub fn joinPaths(allocator: Allocator, first_path: []const u8, second_path: []const u8) ![]u8 {
    // If second path is absolute, use it directly
    if (path.isAbsolutePath(second_path)) {
        return allocator.dupe(u8, second_path);
    }

    if (first_path.len == 0) {
        return allocator.dupe(u8, second_path);
    }

    if (second_path.len == 0) {
        return allocator.dupe(u8, first_path);
    }

    // Get the appropriate slash for the platform
    const slash: u8 = if (builtin.os.tag == .windows) '\\' else '/';

    // Check if first_path already ends with a slash
    const needs_slash = first_path.len > 0 and first_path[first_path.len - 1] != '/' and
        first_path[first_path.len - 1] != '\\';

    // Calculate the total length needed
    const total_len = first_path.len + (if (needs_slash) @as(usize, 1) else @as(usize, 0)) + second_path.len;

    // Allocate memory for the joined path
    var result = try allocator.alloc(u8, total_len);

    // Copy the first path
    @memcpy(result[0..first_path.len], first_path);

    // Add slash if needed
    if (needs_slash) {
        result[first_path.len] = slash;
    }

    // Copy the second path
    @memcpy(result[first_path.len + (if (needs_slash) @as(usize, 1) else @as(usize, 0)) ..], second_path);

    // Clean the path to handle any ".." or "." components
    const cleaned_path = try path.cleanPath(allocator, result);

    // Free the intermediate result
    allocator.free(result);

    return cleaned_path;
}
