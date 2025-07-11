const std = @import("std");

// Re-export individual modules
pub const file = @import("file.zig");
pub const dir = @import("dir.zig");
pub const path = @import("path.zig");

// Re-export commonly used functions directly at the fs level
pub const getCwd = file.getCwd;
pub const fileExists = file.exists;
pub const createDirectory = dir.create;

// Path operations
pub const normalizePath = path.normalizePath;
pub const cleanPath = path.cleanPath;
pub const realPath = path.realPath;
pub const isAbsolutePath = path.isAbsolutePath;
pub const PathResolutionOptions = path.PathResolutionOptions;

// Additional filesystem utilities that combine functionality from both file and dir
