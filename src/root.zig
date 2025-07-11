//! zglob - A glob pattern matching library ported from Rust
//! This module exports functions for glob pattern matching
const std = @import("std");

// Import the glob matcher
pub const match = @import("match.zig");

// Import the glob file finder
const glob_mod = @import("glob.zig");
// Import filesystem utilities
const fs_mod = @import("fs.zig");

// Export the main functions directly at the root level for convenience
pub const globMatch = match.globMatch;
pub const globMatchWithCaptures = match.globMatchWithCaptures;
pub const Capture = match.Capture;
pub const MatchGlob = match.MatchGlob;

// Export the glob file finder functions
pub const glob = glob_mod.glob;
pub const globWithCwd = glob_mod.globWithCwd;
pub const zGlob = glob_mod.zGlob;
// getCwd is now only available through the Fs struct
pub const Fs = fs_mod.Fs;

// Export the fs submodule (simple approach)
pub const fs = fs_mod;
