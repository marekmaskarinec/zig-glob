const std = @import("std");
const fsModule = @import("fs.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Create an Fs instance
    var fs = fsModule.Fs.init(allocator);

    // Get current directory
    const cwd_null = try fs.getCwd();
    defer allocator.free(cwd_null);

    // Print out the current directory
    std.debug.print("Current directory: {s}\n", .{cwd_null});

    // Test if we can use the current directory without error
    var dir_handle = try std.fs.cwd().openDir(cwd_null, .{});
    dir_handle.close();

    std.debug.print("Successfully opened directory\n", .{});
}
