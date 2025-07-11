const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Test with invalid UTF-8 sequences in the glob pattern
test "invalid UTF-8 in glob pattern" {
    // Invalid UTF-8 sequence: 0xF0, 0x28, 0x8C, 0x28 is an invalid 4-byte sequence
    const invalid_glob = [_]u8{ 0xF0, 0x28, 0x8C, 0x28 };
    try testing.expect(!zglob.globMatch(&invalid_glob, "abc"));
}

// Test with invalid UTF-8 sequences in the path
test "invalid UTF-8 in path" {
    // Invalid UTF-8 sequence: 0xC0, 0xAF is an overlong encoding
    const invalid_path = [_]u8{ 0xC0, 0xAF, 0x61, 0x62 };
    try testing.expect(!zglob.globMatch("*", &invalid_path));
}

// Test with invalid UTF-8 sequences in both glob and path
test "invalid UTF-8 in both glob and path" {
    // Invalid UTF-8 sequence: 0xED, 0xA0, 0x80 is a surrogate codepoint
    const invalid_glob = [_]u8{ 0xED, 0xA0, 0x80, '*' };
    // Invalid UTF-8 sequence: 0x80 is a continuation byte without a lead byte
    const invalid_path = [_]u8{ 'a', 'b', 0x80, 'c' };
    try testing.expect(!zglob.globMatch(&invalid_glob, &invalid_path));
}

// Test with captures and invalid UTF-8
test "invalid UTF-8 with captures" {
    // Invalid UTF-8 sequence: 0xFF is never valid in UTF-8
    const invalid_glob = [_]u8{ '*', 0xFF, '*' };
    const path = "abc";

    const captures = zglob.globMatchWithCaptures(&invalid_glob, path, testing.allocator);
    try testing.expect(captures == null);
}

// Test with different types of invalid UTF-8 sequences
test "various invalid UTF-8 sequences" {
    // Incomplete sequence: 0xC2 without continuation byte
    const incomplete = [_]u8{0xC2};
    // Overlong encoding of ASCII character 'a'
    const overlong = [_]u8{ 0xC1, 0x81 };
    // Out of range codepoint (larger than U+10FFFF)
    const out_of_range = [_]u8{ 0xF7, 0xBF, 0xBF, 0xBF };
    // Unexpected continuation byte
    const unexpected = [_]u8{0x80};
    // Invalid sequence in the middle
    const middle_invalid = [_]u8{ 'a', 'b', 0xE0, 0x80, 'c' };

    try testing.expect(!zglob.globMatch(&incomplete, "abc"));
    try testing.expect(!zglob.globMatch(&overlong, "abc"));
    try testing.expect(!zglob.globMatch(&out_of_range, "abc"));
    try testing.expect(!zglob.globMatch(&unexpected, "abc"));
    try testing.expect(!zglob.globMatch(&middle_invalid, "abc"));

    try testing.expect(!zglob.globMatch("abc", &incomplete));
    try testing.expect(!zglob.globMatch("abc", &overlong));
    try testing.expect(!zglob.globMatch("abc", &out_of_range));
    try testing.expect(!zglob.globMatch("abc", &unexpected));
    try testing.expect(!zglob.globMatch("abc", &middle_invalid));
}

// Test with captures and various invalid UTF-8 sequences
test "captures with various invalid UTF-8 sequences" {
    // Incomplete sequence: 0xC2 without continuation byte
    const incomplete = [_]u8{0xC2};
    // Overlong encoding of ASCII character 'a'
    const overlong = [_]u8{ 0xC1, 0x81 };
    // Out of range codepoint (larger than U+10FFFF)
    const out_of_range = [_]u8{ 0xF7, 0xBF, 0xBF, 0xBF };
    // Unexpected continuation byte
    const unexpected = [_]u8{0x80};
    // Invalid sequence in the middle
    const middle_invalid = [_]u8{ 'a', 'b', 0xE0, 0x80, 'c' };

    try testing.expect(zglob.globMatchWithCaptures(&incomplete, "abc", testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures(&overlong, "abc", testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures(&out_of_range, "abc", testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures(&unexpected, "abc", testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures(&middle_invalid, "abc", testing.allocator) == null);

    try testing.expect(zglob.globMatchWithCaptures("abc", &incomplete, testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures("abc", &overlong, testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures("abc", &out_of_range, testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures("abc", &unexpected, testing.allocator) == null);
    try testing.expect(zglob.globMatchWithCaptures("abc", &middle_invalid, testing.allocator) == null);
}

// Test with multiple invalid UTF-8 bytes in a row
test "multiple invalid UTF-8 bytes" {
    // A sequence with multiple invalid UTF-8 bytes
    const invalid_sequence = [_]u8{ 0xC0, 0xC0, 0xC0, 0xC0 };
    try testing.expect(!zglob.globMatch(&invalid_sequence, "abc"));
    try testing.expect(!zglob.globMatch("abc", &invalid_sequence));
    try testing.expect(zglob.globMatchWithCaptures(&invalid_sequence, "abc", testing.allocator) == null);
}

// Test with invalid UTF-8 sequences of different lengths
test "invalid UTF-8 sequences of different lengths" {
    // 2-byte sequence with invalid second byte
    const invalid_2byte = [_]u8{ 0xC2, 0x00 };
    // 3-byte sequence with invalid third byte
    const invalid_3byte = [_]u8{ 0xE0, 0xA0, 0x00 };
    // 4-byte sequence with invalid fourth byte
    const invalid_4byte = [_]u8{ 0xF0, 0x90, 0x80, 0x00 };

    try testing.expect(!zglob.globMatch(&invalid_2byte, "abc"));
    try testing.expect(!zglob.globMatch(&invalid_3byte, "abc"));
    try testing.expect(!zglob.globMatch(&invalid_4byte, "abc"));
}
