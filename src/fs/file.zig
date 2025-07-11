const std = @import("std");
const cwd = @import("./dir.zig").getCwd();

// Re-export the getCwd function
pub const getCwd = cwd.getCwd;

// Other filesystem operations
pub fn exists(path: []const u8) bool {
    return std.fs.accessAbsolute(path, .{}) == .{};
}

pub fn isFile(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .File;
}

// More file-specific operations
