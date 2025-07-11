const std = @import("std");

// Import any other dependencies you need
const zDir = @import("./fs/dir.zig");
const zPath = @import("./fs/path.zig");

/// Fs struct for object-oriented filesystem operations
/// Uses a provided allocator for all memory operations
pub const Fs = struct {
    allocator: std.mem.Allocator,

    /// Initialize a new Fs instance with the given allocator
    pub fn init(allocator: std.mem.Allocator) Fs {
        return Fs{ .allocator = allocator };
    }

    /// Get the current working directory
    pub fn getCwd(self: Fs) ![:0]const u8 {
        return zDir.getCwd(self.allocator);
    }

    /// Check if a file exists
    pub fn fileExists(self: Fs, path: []const u8) bool {
        _ = self; // self not used in this function
        if (std.fs.path.isAbsolute(path)) {
            _ = std.fs.cwd().access(path, .{}) catch return false;
        }
        _ = std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }

    /// Check if a path is a directory
    pub fn isDirectory(self: Fs, path: []const u8) bool {
        _ = self; // self not used in this function
        const stat = std.fs.cwd().statFile(path) catch return false;
        return stat.kind == .directory;
    }

    /// Clean a path by resolving "." and ".." components
    pub fn cleanPath(self: Fs, path: []const u8) ![]u8 {
        return zPath.cleanPath(self.allocator, path);
    }

    /// Normalize a path
    pub fn normalizePath(self: Fs, base_dir: []const u8, path: []const u8, options: zPath.PathResolutionOptions) ![]u8 {
        return zPath.normalizePath(self.allocator, base_dir, path, options);
    }

    /// Get real path
    pub fn realPath(self: Fs, path: []const u8) ![]u8 {
        return zPath.realPath(self.allocator, path);
    }

    /// Check if the path is absolute
    pub fn isAbsolutePath(self: Fs, path: []const u8) bool {
        _ = self; // self not used in this function
        return zPath.isAbsolutePath(path);
    }
};

// getCwd function is now only available through the Fs struct
// The direct export has been removed

// Add other filesystem related functions
pub fn fileExists(path: []const u8) bool {
    if (std.fs.path.isAbsolute(path)) {
        _ = std.fs.cwd().access(path, .{}) catch return false;
    }
    _ = std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

pub fn isDirectory(path: []const u8) bool {
    // Implementation
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

// Add more filesystem functions as needed

// Path normalization functions
pub const normalizePath = zPath.normalizePath;
pub const cleanPath = zPath.cleanPath;
pub const realPath = zPath.realPath;
pub const isAbsolutePath = zPath.isAbsolutePath;
pub const PathResolutionOptions = zPath.PathResolutionOptions;
