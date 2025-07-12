const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Basic tests for extglob patterns
test "extglob basic matching - negation" {
    // !(pattern) - matches anything except the pattern
    try testing.expect(zglob.globMatch("!(abc)", "def"));
    try testing.expect(zglob.globMatch("!(abc)", "ab"));
    try testing.expect(!zglob.globMatch("!(abc)", "abc"));
    try testing.expect(zglob.globMatch("a!(b)c", "adc"));
    try testing.expect(zglob.globMatch("a!(b)c", "aac"));
    try testing.expect(!zglob.globMatch("a!(b)c", "abc"));
}

test "extglob basic matching - optional" {
    // ?(pattern) - matches zero or one occurrence of the pattern
    try testing.expect(zglob.globMatch("?(abc)", ""));
    try testing.expect(zglob.globMatch("?(abc)", "abc"));
    try testing.expect(!zglob.globMatch("?(abc)", "abcabc"));
    try testing.expect(zglob.globMatch("a?(b)c", "ac"));
    try testing.expect(zglob.globMatch("a?(b)c", "abc"));
    try testing.expect(!zglob.globMatch("a?(b)c", "abbc"));
}

test "extglob basic matching - zero or more" {
    // *(pattern) - matches zero or more occurrences of the pattern
    try testing.expect(zglob.globMatch("*(abc)", ""));
    try testing.expect(zglob.globMatch("*(abc)", "abc"));
    try testing.expect(zglob.globMatch("*(abc)", "abcabc"));
    try testing.expect(zglob.globMatch("*(abc)", "abcabcabc"));
    try testing.expect(zglob.globMatch("a*(b)c", "ac"));
    try testing.expect(zglob.globMatch("a*(b)c", "abc"));
    try testing.expect(zglob.globMatch("a*(b)c", "abbc"));
    try testing.expect(zglob.globMatch("a*(b)c", "abbbc"));
}

test "extglob basic matching - one or more" {
    // +(pattern) - matches one or more occurrences of the pattern
    try testing.expect(!zglob.globMatch("+(abc)", ""));
    try testing.expect(zglob.globMatch("+(abc)", "abc"));
    try testing.expect(zglob.globMatch("+(abc)", "abcabc"));
    try testing.expect(zglob.globMatch("+(abc)", "abcabcabc"));
    try testing.expect(!zglob.globMatch("a+(b)c", "ac"));
    try testing.expect(zglob.globMatch("a+(b)c", "abc"));
    try testing.expect(zglob.globMatch("a+(b)c", "abbc"));
    try testing.expect(zglob.globMatch("a+(b)c", "abbbc"));
}

test "extglob basic matching - exactly one" {
    // @(pattern) - matches exactly one occurrence of the pattern
    try testing.expect(!zglob.globMatch("@(abc)", ""));
    try testing.expect(zglob.globMatch("@(abc)", "abc"));
    try testing.expect(!zglob.globMatch("@(abc)", "abcabc"));
    try testing.expect(!zglob.globMatch("a@(b)c", "ac"));
    try testing.expect(zglob.globMatch("a@(b)c", "abc"));
    try testing.expect(!zglob.globMatch("a@(b)c", "abbc"));
}

test "extglob with alternations" {
    // Test basic alternation using |
    try testing.expect(zglob.globMatch("@(abc|def)", "abc"));
    try testing.expect(zglob.globMatch("@(abc|def)", "def"));
    try testing.expect(!zglob.globMatch("@(abc|def)", "ghi"));
    try testing.expect(!zglob.globMatch("@(abc|def)", ""));

    // Negation with alternations
    try testing.expect(!zglob.globMatch("!(abc|def)", "abc"));
    try testing.expect(!zglob.globMatch("!(abc|def)", "def"));
    try testing.expect(zglob.globMatch("!(abc|def)", "ghi"));
    try testing.expect(zglob.globMatch("!(abc|def)", ""));

    // Optional with alternations
    try testing.expect(zglob.globMatch("?(abc|def)", ""));
    try testing.expect(zglob.globMatch("?(abc|def)", "abc"));
    try testing.expect(zglob.globMatch("?(abc|def)", "def"));
    try testing.expect(!zglob.globMatch("?(abc|def)", "ghi"));
}

test "extglob with wildcards" {
    // Mix extglobs with regular glob patterns
    try testing.expect(zglob.globMatch("a!(b*)c", "adc"));
    try testing.expect(zglob.globMatch("a!(b*)c", "aac"));
    try testing.expect(!zglob.globMatch("a!(b*)c", "abc"));
    try testing.expect(!zglob.globMatch("a!(b*)c", "abbc"));

    try testing.expect(zglob.globMatch("a+(b*)c", "abbc"));
    try testing.expect(zglob.globMatch("a+(b*)c", "abbbc"));
    try testing.expect(zglob.globMatch("a+(b*)c", "abxc"));
    try testing.expect(zglob.globMatch("a+(b*)c", "abxybzc"));
    try testing.expect(!zglob.globMatch("a+(b*)c", "ac"));
}
