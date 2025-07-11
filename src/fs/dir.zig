const std = @import("std");

const isWindows = @import("builtin").os.tag == .windows;

pub fn create(path: []const u8) !void {
    return std.fs.cwd().makePath(path);
}

pub fn remove(path: []const u8) !void {
    return std.fs.deleteTree(path);
}

/// Get the current working directory using the provided allocator
/// The caller is responsible for freeing the returned memory
/// @param allocator The allocator to use for the result
/// Note: This function is intended for internal use by the Fs struct
pub fn getCwd(allocator: std.mem.Allocator) ![:0]const u8 {
    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    return try allocator.dupeZ(u8, cwd);
}
