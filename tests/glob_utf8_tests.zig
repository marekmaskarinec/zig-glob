const std = @import("std");
const zglob = @import("zglob");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Basic tests with UTF-8 characters
test "UTF-8 basic matching" {
    try testing.expect(zglob.globMatch("αβγ", "αβγ")); // Greek letters
    try testing.expect(zglob.globMatch("*", "αβγ"));
    try testing.expect(zglob.globMatch("*γ", "αβγ")); // Match ending
    try testing.expect(!zglob.globMatch("*β", "αβγ")); // No match ending
    try testing.expect(zglob.globMatch("α*", "αβγ")); // Match beginning
    try testing.expect(!zglob.globMatch("β*", "αβγ")); // No match beginning
    try testing.expect(zglob.globMatch("α*", "α")); // Single char match
    try testing.expect(zglob.globMatch("*α", "α")); // Single char match end
    try testing.expect(zglob.globMatch("α*β*γ*δ*ε*", "αχβχγχδχε")); // Multi wildcard
    try testing.expect(zglob.globMatch("α*β*γ*δ*ε*", "αχβχγχδχεχχχ")); // Multi wildcard with extra chars
    try testing.expect(zglob.globMatch("α*β?γ*χ", "αβχββχδβχεβχγζζχ")); // Mixed wildcards
    try testing.expect(!zglob.globMatch("α*β?γ*χ", "αβχββχδβχεβχγζζψ")); // No match mixed wildcards
}

test "UTF-8 path matching" {
    try testing.expect(zglob.globMatch("α/*/τέστ", "α/φω/τέστ")); // Path with UTF-8
    try testing.expect(!zglob.globMatch("α/*/τέστ", "α/φω/βαρ/τέστ"));
    try testing.expect(zglob.globMatch("α/**/τέστ", "α/φω/τέστ"));
    try testing.expect(zglob.globMatch("α/**/τέστ", "α/φω/βαρ/τέστ"));
    try testing.expect(zglob.globMatch("α/**/β/γ", "α/φω/βαρ/β/γ"));
    try testing.expect(zglob.globMatch("α\\*β", "α*β")); // Escaped UTF-8
    try testing.expect(!zglob.globMatch("α\\*β", "αχβ"));
}

test "UTF-8 character classes" {
    try testing.expect(zglob.globMatch("[αβγ]", "α"));
    try testing.expect(zglob.globMatch("[αβγ]", "β"));
    try testing.expect(zglob.globMatch("[αβγ]", "γ"));
    try testing.expect(!zglob.globMatch("[αβγ]", "δ"));
    try testing.expect(zglob.globMatch("χ[αβγ]χ", "χαχ"));
    try testing.expect(zglob.globMatch("χ[αβγ]χ", "χβχ"));
    try testing.expect(zglob.globMatch("χ[αβγ]χ", "χγχ"));
    try testing.expect(!zglob.globMatch("χ[αβγ]χ", "χδχ"));
    try testing.expect(!zglob.globMatch("χ[αβγ]χ", "χαψ"));
    try testing.expect(zglob.globMatch("[?]", "?")); // Special characters in class
    try testing.expect(!zglob.globMatch("[?]", "α"));
    try testing.expect(zglob.globMatch("[*]", "*"));
    try testing.expect(!zglob.globMatch("[*]", "α"));
}

test "UTF-8 character ranges" {
    try testing.expect(zglob.globMatch("[α-γχ]", "α"));
    try testing.expect(zglob.globMatch("[α-γχ]", "β"));
    try testing.expect(zglob.globMatch("[α-γχ]", "γ"));
    try testing.expect(!zglob.globMatch("[α-γχ]", "δ"));
    try testing.expect(zglob.globMatch("[α-γχ]", "χ"));
}

test "UTF-8 negated character classes" {
    try testing.expect(!zglob.globMatch("[^αβγ]", "α"));
    try testing.expect(!zglob.globMatch("[^αβγ]", "β"));
    try testing.expect(!zglob.globMatch("[^αβγ]", "γ"));
    try testing.expect(zglob.globMatch("[^αβγ]", "δ"));
    try testing.expect(!zglob.globMatch("[!αβγ]", "α"));
    try testing.expect(!zglob.globMatch("[!αβγ]", "β"));
    try testing.expect(!zglob.globMatch("[!αβγ]", "γ"));
    try testing.expect(zglob.globMatch("[!αβγ]", "δ"));
    try testing.expect(zglob.globMatch("[\\!]", "!")); // Escaped char in class
}

test "UTF-8 combined patterns" {
    try testing.expect(zglob.globMatch("α*β*[γψ]*δ*ε*", "αχβχγχδχεχχχ"));
    try testing.expect(zglob.globMatch("α*β*[γψ]*δ*ε*", "αχβχψχδχεχχχ"));
    try testing.expect(zglob.globMatch("α*β*[γψ]*δ*ε*", "αχβχχχψχδχεχχχ"));
}

test "UTF-8 braces" {
    try testing.expect(zglob.globMatch("τεστ.{τζπγ,πνγ}", "τεστ.τζπγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζπγ,πνγ}", "τεστ.πνγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζ*γ,π*γ}", "τεστ.τζπγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζ*γ,π*γ}", "τεστ.τζπχχχγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζ*γ,π*γ}", "τεστ.τζχγ"));
    try testing.expect(!zglob.globMatch("τεστ.{τζ*γ,π*γ}", "τεστ.τζντ"));
    try testing.expect(zglob.globMatch("τεστ.{τζ*γ,τζ*γ}", "τεστ.τζνγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζπγ,π*γ}", "τεστ.πνγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζπγ,π*γ}", "τεστ.πχγ"));
    try testing.expect(!zglob.globMatch("τεστ.{τζπγ,π*γ}", "τεστ.πντ"));
    try testing.expect(zglob.globMatch("τεστ.{τζπεγ,πνγ}", "τεστ.τζπεγ"));
    try testing.expect(!zglob.globMatch("τεστ.{τζπεγ,πνγ}", "τεστ.τζπγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζπεγ,πνγ}", "τεστ.πνγ"));
    try testing.expect(zglob.globMatch("τεστ.{τζπ\\,γ,πνγ}", "τεστ.τζπ,γ")); // Escaped comma
    try testing.expect(!zglob.globMatch("τεστ.{τζπ\\,γ,πνγ}", "τεστ.τζχγ"));
}

test "UTF-8 path with braces" {
    try testing.expect(zglob.globMatch("τεστ/{φοο,βαρ}/βαζ", "τεστ/φοο/βαζ"));
    try testing.expect(zglob.globMatch("τεστ/{φοο,βαρ}/βαζ", "τεστ/βαρ/βαζ"));
    try testing.expect(!zglob.globMatch("τεστ/{φοο,βαρ}/βαζ", "τεστ/βαζ/βαζ"));
    try testing.expect(zglob.globMatch("τεστ/{φοο*,βαρ*}/βαζ", "τεστ/φοοοοοο/βαζ"));
    try testing.expect(zglob.globMatch("τεστ/{φοο*,βαρ*}/βαζ", "τεστ/βαρρρρρ/βαζ"));
    try testing.expect(zglob.globMatch("τεστ/{*φοο,*βαρ}/βαζ", "τεστ/χχχχφοο/βαζ"));
    try testing.expect(zglob.globMatch("τεστ/{*φοο,*βαρ}/βαζ", "τεστ/χχχχβαρ/βαζ"));
    try testing.expect(zglob.globMatch("τεστ/{φοο/**,βαρ}/βαζ", "τεστ/βαρ/βαζ"));
    try testing.expect(!zglob.globMatch("τεστ/{φοο/**,βαρ}/βαζ", "τεστ/βαρ/τεστ/βαζ"));
}

test "UTF-8 complex patterns" {
    try testing.expect(!zglob.globMatch("*.τχτ", "σομε/βιγ/πατη/το/τηε/νεεδλε.τχτ"));
    try testing.expect(zglob.globMatch("σομε/**/νεεδλε.{τζσ,τσχ,μδχ,τσ,τζσχ,τχτ}", "σομε/α/βιγγερ/πατη/το/τηε/γραζψ/νεεδλε.τχτ"));
    try testing.expect(zglob.globMatch("σομε/**/{α,β,γ}/**/νεεδλε.τχτ", "σομε/φοο/α/βιγγερ/πατη/το/τηε/γραζψ/νεεδλε.τχτ"));
    try testing.expect(!zglob.globMatch("σομε/**/{α,β,γ}/**/νεεδλε.τχτ", "σομε/φοο/δ/βιγγερ/πατη/το/τηε/γραζψ/νεεδλε.τχτ"));
    try testing.expect(zglob.globMatch("α/{α{α,β},β}", "α/αα"));
    try testing.expect(zglob.globMatch("α/{α{α,β},β}", "α/αβ"));
    try testing.expect(!zglob.globMatch("α/{α{α,β},β}", "α/αγ"));
    try testing.expect(zglob.globMatch("α/{α{α,β},β}", "α/β"));
    try testing.expect(!zglob.globMatch("α/{α{α,β},β}", "α/γ"));
    try testing.expect(zglob.globMatch("α/{β,γ[}]*}", "α/β"));
    try testing.expect(zglob.globMatch("α/{β,γ[}]*}", "α/γ}χχ"));
}

// Bash tests ported from micromatch, with UTF-8
test "UTF-8 bash basic" {
    try testing.expect(!zglob.globMatch("α*", "*"));
    try testing.expect(!zglob.globMatch("α*", "**"));
    try testing.expect(!zglob.globMatch("α*", "\\*"));
    try testing.expect(!zglob.globMatch("α*", "α/*"));
    try testing.expect(!zglob.globMatch("α*", "β"));
    try testing.expect(!zglob.globMatch("α*", "βγ"));
    try testing.expect(!zglob.globMatch("α*", "βγδ"));
    try testing.expect(!zglob.globMatch("α*", "βδιρ/"));
    try testing.expect(!zglob.globMatch("α*", "Βεωαρε"));
    try testing.expect(zglob.globMatch("α*", "α"));
    try testing.expect(zglob.globMatch("α*", "αβ"));
    try testing.expect(zglob.globMatch("α*", "αβγ"));
}

test "UTF-8 bash escaped" {
    try testing.expect(!zglob.globMatch("\\α*", "*"));
    try testing.expect(!zglob.globMatch("\\α*", "**"));
    try testing.expect(!zglob.globMatch("\\α*", "\\*"));
    try testing.expect(zglob.globMatch("\\α*", "α"));
    try testing.expect(!zglob.globMatch("\\α*", "α/*"));
    try testing.expect(zglob.globMatch("\\α*", "αβγ"));
    try testing.expect(zglob.globMatch("\\α*", "αβδ"));
    try testing.expect(zglob.globMatch("\\α*", "αβε"));
    try testing.expect(!zglob.globMatch("\\α*", "β"));
    try testing.expect(!zglob.globMatch("\\α*", "ββ"));
    try testing.expect(!zglob.globMatch("\\α*", "βγδ"));
    try testing.expect(!zglob.globMatch("\\α*", "βδιρ/"));
    try testing.expect(!zglob.globMatch("\\α*", "Βεωαρε"));
    try testing.expect(!zglob.globMatch("\\α*", "γ"));
    try testing.expect(!zglob.globMatch("\\α*", "γα"));
    try testing.expect(!zglob.globMatch("\\α*", "γβ"));
    try testing.expect(!zglob.globMatch("\\α*", "δ"));
    try testing.expect(!zglob.globMatch("\\α*", "δδ"));
    try testing.expect(!zglob.globMatch("\\α*", "δε"));
}

test "UTF-8 bash directories" {
    try testing.expect(!zglob.globMatch("β*/", "*"));
    try testing.expect(!zglob.globMatch("β*/", "**"));
    try testing.expect(!zglob.globMatch("β*/", "\\*"));
    try testing.expect(!zglob.globMatch("β*/", "α"));
    try testing.expect(!zglob.globMatch("β*/", "α/*"));
    try testing.expect(!zglob.globMatch("β*/", "αβγ"));
    try testing.expect(!zglob.globMatch("β*/", "αβδ"));
    try testing.expect(!zglob.globMatch("β*/", "αβε"));
    try testing.expect(!zglob.globMatch("β*/", "β"));
    try testing.expect(!zglob.globMatch("β*/", "ββ"));
    try testing.expect(!zglob.globMatch("β*/", "βγδ"));
    try testing.expect(zglob.globMatch("β*/", "βδιρ/"));
    try testing.expect(!zglob.globMatch("β*/", "Βεωαρε"));
    try testing.expect(!zglob.globMatch("β*/", "γ"));
    try testing.expect(!zglob.globMatch("β*/", "γα"));
    try testing.expect(!zglob.globMatch("β*/", "γβ"));
    try testing.expect(!zglob.globMatch("β*/", "δ"));
    try testing.expect(!zglob.globMatch("β*/", "δδ"));
    try testing.expect(!zglob.globMatch("β*/", "δε"));
}

// Test with UTF-8 captures
test "UTF-8 captures basic" {
    var captures = zglob.globMatchWithCaptures("α*γ", "αβγ", testing.allocator) orelse {
        try testing.expect(false); // This should not happen
        return;
    };
    defer captures.deinit();

    try testing.expectEqual(@as(usize, 1), captures.items.len);
    // In UTF-8, "α" is 2 bytes (0xCE 0xB1), so "β" starts at byte position 2
    try testing.expectEqual(@as(usize, 2), captures.items[0].start);
    // "β" is also 2 bytes (0xCE 0xB2), so its end position is 4
    try testing.expectEqual(@as(usize, 4), captures.items[0].end);
}

// Mixed ASCII and UTF-8
test "mixed ASCII and UTF-8" {
    try testing.expect(zglob.globMatch("abc*αβγ", "abcxyzαβγ"));
    try testing.expect(zglob.globMatch("α*xyz", "αβγxyz"));
    try testing.expect(zglob.globMatch("a*β*c", "axxβyyc"));
    try testing.expect(zglob.globMatch("[aα][bβ][cγ]", "aβc"));
    try testing.expect(zglob.globMatch("[aα][bβ][cγ]", "αbγ"));
    // Modified test: Use Chinese characters in the pattern to match Chinese characters in the path
    try testing.expect(zglob.globMatch("[a-z]*[世-龠]", "hello世界"));
    try testing.expect(zglob.globMatch("[a-z]*[α-ω]", "helloα"));
    try testing.expect(!zglob.globMatch("[a-z][α-ω]", "aA"));
    try testing.expect(zglob.globMatch("a?β", "a世β")); // Question mark should match a single UTF-8 character
    try testing.expect(!zglob.globMatch("a?β", "axxβ")); // But not multiple characters
}

// Emoji tests
test "emoji patterns" {
    try testing.expect(zglob.globMatch("👍", "👍"));
    try testing.expect(zglob.globMatch("👍*", "👍👎"));
    try testing.expect(zglob.globMatch("*👎", "👍👎"));
    try testing.expect(zglob.globMatch("👍*👎", "👍😀👎"));
    try testing.expect(zglob.globMatch("[👍👎]", "👍"));
    try testing.expect(zglob.globMatch("[👍👎]", "👎"));
    try testing.expect(!zglob.globMatch("[👍👎]", "😀"));
    try testing.expect(zglob.globMatch("👍?👎", "👍😀👎"));
    try testing.expect(!zglob.globMatch("👍?👎", "👍😀😀👎"));
    try testing.expect(zglob.globMatch("*[👍👎]*", "hello👍world"));
    try testing.expect(zglob.globMatch("hello.{👍,👎}", "hello.👍"));
    try testing.expect(zglob.globMatch("hello.{👍,👎}", "hello.👎"));
    try testing.expect(!zglob.globMatch("hello.{👍,👎}", "hello.😀"));
}

// CJK character tests
test "CJK patterns" {
    try testing.expect(zglob.globMatch("你*", "你好"));
    try testing.expect(zglob.globMatch("*好", "你好"));
    try testing.expect(zglob.globMatch("你?好", "你是好"));
    try testing.expect(!zglob.globMatch("你?好", "你是是好"));
    try testing.expect(zglob.globMatch("[你我他]", "你"));
    try testing.expect(zglob.globMatch("[你我他]", "我"));
    try testing.expect(!zglob.globMatch("[你我他]", "她"));
    try testing.expect(zglob.globMatch("世界.{你,我,他}", "世界.你"));
    try testing.expect(zglob.globMatch("世界.{你,我,他}", "世界.他"));
    try testing.expect(!zglob.globMatch("世界.{你,我,他}", "世界.她"));
}
