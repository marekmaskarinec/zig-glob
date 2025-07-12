const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const unicode = std.unicode;

/// A range of indices in a string
pub const Capture = struct {
    start: usize,
    end: usize,
};

pub const MatchGlob = struct {
    allocator: Allocator,

    /// Initialize a new MatchGlob instance with the given allocator
    pub fn init(allocator: Allocator) MatchGlob {
        return MatchGlob{ .allocator = allocator };
    }

    /// Match a glob pattern against a path
    pub fn match(self: MatchGlob, glob: []const u8, path: []const u8) bool {
        _ = self; // self not used directly in this function
        return globMatch(glob, path);
    }

    /// Match a glob pattern against a path and collect captures
    pub fn matchWithCaptures(self: MatchGlob, glob: []const u8, path: []const u8) ?std.ArrayList(Capture) {
        return globMatchWithCaptures(glob, path, self.allocator);
    }
};

/// UTF-8 utility functions
const Utf8 = struct {
    /// Get the byte length of a UTF-8 code point
    inline fn codepointLen(c: u8) usize {
        return unicode.utf8ByteSequenceLength(c) catch 1;
    }

    /// Decode a UTF-8 codepoint from a byte slice
    inline fn decode(bytes: []const u8) u21 {
        // First validate that we have a valid UTF-8 sequence to avoid panics
        if (bytes.len == 0) return 0xFFFD;

        const len = codepointLen(bytes[0]);
        if (len > bytes.len) return 0xFFFD; // Incomplete sequence

        // Handle different sequence lengths
        if (len == 1) { // ASCII
            return bytes[0];
        } else {
            // For multi-byte sequences, safely handle decoding
            if (unicode.utf8ValidateSlice(bytes[0..len])) {
                return unicode.utf8Decode(bytes[0..len]) catch 0xFFFD;
            } else { // Invalid sequence
                return 0xFFFD;
            }
        }
    }

    inline fn nextCodepoint(str: []const u8, index: usize) usize {
        if (index >= str.len) return str.len;
        return index + codepointLen(str[index]);
    }
};

/// State for a glob matching operation
const State = struct {
    // Character indices into the glob and path strings - must remain usize
    path_index: usize,
    glob_index: usize,

    // Current index into the captures list - can be u32 for better performance
    capture_index: u32,

    // When we hit a * or **, we store state for backtracking
    wildcard: Wildcard,
    globstar: Wildcard,

    fn init() State {
        return .{
            .path_index = 0,
            .glob_index = 0,
            .capture_index = 0,
            .wildcard = Wildcard.init(),
            .globstar = Wildcard.init(),
        };
    }

    fn backtrack(self: *State) void {
        self.glob_index = self.wildcard.glob_index;
        self.path_index = self.wildcard.path_index;
        self.capture_index = self.wildcard.capture_index;
    }

    fn beginCapture(self: *const State, captures: ?*std.ArrayList(Capture), capture: Capture) void {
        if (captures) |c| {
            const idx = @as(usize, self.capture_index);
            if (idx < c.items.len) {
                c.items[idx] = capture;
            } else {
                // Safety check to prevent excessive captures
                if (c.items.len >= MAX_CAPTURES) return;
                c.append(capture) catch {};
            }
        }
    }

    fn extendCapture(self: *const State, captures: ?*std.ArrayList(Capture)) void {
        if (captures) |c| {
            const idx = @as(usize, self.capture_index);
            if (idx < c.items.len) {
                c.items[idx].end = self.path_index;
            }
        }
    }

    fn endCapture(self: *State, captures: ?*std.ArrayList(Capture)) void {
        if (captures) |c| {
            const idx = @as(usize, self.capture_index);
            if (idx < c.items.len) {
                self.capture_index += 1;
            }
        }
    }

    fn addCharCapture(self: *State, captures: ?*std.ArrayList(Capture), path: []const u8) void {
        const char_len = if (self.path_index < path.len) Utf8.codepointLen(path[self.path_index]) else 1;
        self.beginCapture(captures, .{ .start = self.path_index, .end = self.path_index + char_len });
        self.endCapture(captures);
    }

    fn skipBraces(
        self: *State,
        glob: []const u8,
        captures: ?*std.ArrayList(Capture),
        stop_on_comma: bool,
    ) BraceState {
        var braces: usize = 1;
        var in_brackets = false;
        var capture_index = @as(usize, self.capture_index) + 1;

        while (self.glob_index < glob.len and braces > 0) {
            const c = glob[self.glob_index];

            switch (c) {
                // Skip nested braces
                '{' => {
                    if (!in_brackets) braces += 1;
                },
                '}' => {
                    if (!in_brackets) braces -= 1;
                },
                ',' => if (stop_on_comma and braces == 1 and !in_brackets) {
                    self.glob_index += 1;
                    return .Comma;
                },
                '*', '?', '[' => if (!in_brackets) {
                    if (c == '[') {
                        in_brackets = true;
                    }
                    if (captures) |cap| {
                        if (capture_index < cap.items.len) {
                            cap.items[capture_index] = .{ .start = self.path_index, .end = self.path_index };
                        } else {
                            // Safety check to prevent excessive captures in brace handling
                            if (cap.items.len >= MAX_CAPTURES) {
                                // Skip appending but still increment the index
                            } else {
                                cap.append(.{ .start = self.path_index, .end = self.path_index }) catch {};
                            }
                        }
                        capture_index += 1;
                    }
                    if (c == '*') {
                        if (self.glob_index + 1 < glob.len and glob[self.glob_index + 1] == '*') {
                            self.glob_index = skipGlobstars(glob, self.glob_index + 2) - 2;
                            self.glob_index += 1;
                        }
                    }
                },
                ']' => in_brackets = false,
                '\\' => {
                    self.glob_index += 1;
                },
                else => {},
            }
            self.glob_index += 1;
        }

        if (braces != 0) {
            return .Invalid;
        }

        return .EndBrace;
    }
};

/// Wildcard state for backtracking
const Wildcard = struct {
    // Keep as usize since they're used for string indexing
    glob_index: usize,
    path_index: usize,
    // Using u32 for counter values for potential performance benefit
    capture_index: u32,

    fn init() Wildcard {
        return .{
            .glob_index = 0,
            .path_index = 0,
            .capture_index = 0,
        };
    }
};

/// Possible states when processing braces
const BraceState = enum {
    Invalid,
    Comma,
    EndBrace,
};

/// Maximum allowed depth for brace nesting to prevent stack overflows
const MAX_BRACE_NESTING = 10;

/// Stack for tracking state during brace expansion
const BraceStack = struct {
    stack: [MAX_BRACE_NESTING]State,
    // Counter with small fixed upper bound can be u32
    length: u32,
    // Keep as usize since it represents a position in the path
    longest_brace_match: usize,

    fn init() BraceStack {
        return .{
            .stack = [_]State{State.init()} ** 10,
            .length = 0,
            .longest_brace_match = 0,
        };
    }

    fn push(self: *BraceStack, state: *const State) State {
        // Push old state to the stack and reset current state
        self.stack[@as(usize, self.length)] = state.*;
        self.length += 1;

        return .{
            .path_index = state.path_index,
            .glob_index = state.glob_index + 1,
            .capture_index = state.capture_index + 1,
            .wildcard = Wildcard.init(),
            .globstar = Wildcard.init(),
        };
    }

    fn pop(self: *BraceStack, state: *const State, captures: ?*std.ArrayList(Capture)) State {
        self.length -= 1;
        var new_state = State{
            .path_index = self.longest_brace_match,
            .glob_index = state.glob_index,
            .wildcard = self.stack[@as(usize, self.length)].wildcard,
            .globstar = self.stack[@as(usize, self.length)].globstar,
            .capture_index = self.stack[@as(usize, self.length)].capture_index,
        };

        if (self.length == 0) {
            self.longest_brace_match = 0;
        }

        new_state.extendCapture(captures);

        if (captures) |c| {
            // Convert the length to u32, with safety check
            const len = c.items.len;
            new_state.capture_index = if (len > std.math.maxInt(u32))
                std.math.maxInt(u32)
            else
                @as(u32, @intCast(len));
        }

        return new_state;
    }

    fn last(self: *const BraceStack) *const State {
        return &self.stack[@as(usize, self.length) - 1];
    }
};

/// Unescape a character from a glob pattern
fn unescape(c: *u8, glob: []const u8, glob_index: *usize) bool {
    if (c.* == '\\') {
        glob_index.* += 1;
        if (glob_index.* >= glob.len) {
            // Invalid pattern!
            return false;
        }
        c.* = switch (glob[glob_index.*]) {
            'a' => '\x61',
            'b' => '\x08',
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            else => |ch| ch,
        };
    }
    return true;
}

/// Coalesce multiple ** segments into one
fn skipGlobstars(glob: []const u8, glob_index: usize) usize {
    var index = glob_index;
    while (index + 3 <= glob.len and
        mem.eql(u8, glob[index .. index + 3], "/**"))
    {
        index += 3;
    }
    return index;
}

/// Check if a character is a path separator
fn isSeparator(c: u8) bool {
    return switch (c) {
        '/', '\\' => true,
        else => false,
    };
}

/// Match a glob pattern against a path
pub fn globMatch(glob: []const u8, path: []const u8) bool {
    // Safety check: Validate that the input lengths don't exceed what we can safely handle
    if (glob.len > std.math.maxInt(u32) or path.len > std.math.maxInt(u32)) {
        return false;
    }

    // Validate that the input is valid UTF-8
    if (!unicode.utf8ValidateSlice(glob) or !unicode.utf8ValidateSlice(path)) {
        return false;
    }
    return globMatchInternal(glob, path, null);
}

/// Match a glob pattern against a path and collect captures
pub fn globMatchWithCaptures(glob: []const u8, path: []const u8, allocator: Allocator) ?std.ArrayList(Capture) {
    // Safety check: Validate that the input lengths don't exceed what we can safely handle
    if (glob.len > std.math.maxInt(u32) or path.len > std.math.maxInt(u32)) {
        return null;
    }

    // Validate that the input is valid UTF-8
    if (!unicode.utf8ValidateSlice(glob) or !unicode.utf8ValidateSlice(path)) {
        return null;
    }

    var captures = std.ArrayList(Capture).init(allocator);
    if (globMatchInternal(glob, path, &captures)) {
        return captures;
    }
    captures.deinit();
    return null;
}

/// Maximum number of captures to prevent potential DoS issues with patterns like "*********"
const MAX_CAPTURES = 10000;

/// Internal implementation of glob matching
fn globMatchInternal(glob: []const u8, path: []const u8, captures: ?*std.ArrayList(Capture)) bool {
    // Additional safety check for internal state management
    if (glob.len > std.math.maxInt(u32) or path.len > std.math.maxInt(u32)) {
        return false;
    }

    var state = State.init();
    var brace_stack = BraceStack.init();

    // Check if the pattern is negated with a leading '!' character
    // Multiple negations can occur
    var negated = false;
    while (state.glob_index < glob.len and glob[state.glob_index] == '!') {
        negated = !negated;
        state.glob_index += 1;
    }

    while (state.glob_index < glob.len or state.path_index < path.len) {
        if (state.glob_index < glob.len) {
            const c = glob[state.glob_index];
            switch (c) {
                '*' => {
                    const is_globstar = state.glob_index + 1 < glob.len and glob[state.glob_index + 1] == '*';
                    if (is_globstar) {
                        // Coalesce multiple ** segments into one
                        state.glob_index = skipGlobstars(glob, state.glob_index + 2) - 2;
                    }

                    // If we're on a different glob index than before, start a new capture
                    // Otherwise, extend the active one
                    if (captures) |capture_list| {
                        if (capture_list.items.len == 0 or state.glob_index != state.wildcard.glob_index) {
                            state.wildcard.capture_index = state.capture_index;
                            state.beginCapture(captures, .{ .start = state.path_index, .end = state.path_index });
                        } else {
                            state.extendCapture(captures);
                        }
                    }

                    state.wildcard.glob_index = state.glob_index;
                    // Advance by the length of the UTF-8 codepoint if in bounds
                    state.wildcard.path_index = if (state.path_index < path.len)
                        state.path_index + Utf8.codepointLen(path[state.path_index])
                    else
                        state.path_index + 1;

                    // ** allows path separators, whereas * does not
                    // However, ** must be a full path component, i.e., a/**/b not a**b
                    if (is_globstar) {
                        state.glob_index += 2;

                        if (glob.len == state.glob_index) {
                            // A trailing ** segment without a following separator
                            state.globstar = state.wildcard;
                        } else if ((state.glob_index < 3 or glob[state.glob_index - 3] == '/') and
                            glob[state.glob_index] == '/')
                        {
                            // Matched a full /**/ segment
                            if (state.path_index == 0 or
                                (state.path_index < path.len and isSeparator(path[state.path_index - 1])))
                            {
                                state.endCapture(captures);
                                state.glob_index += 1;
                            }

                            state.globstar = state.wildcard;
                        }
                    } else {
                        state.glob_index += 1;
                    }

                    // If we are in a * segment and hit a separator,
                    // either jump back to a previous ** or end the wildcard
                    if (state.globstar.path_index != state.wildcard.path_index and
                        state.path_index < path.len and isSeparator(path[state.path_index]))
                    {
                        // Special case: don't jump back for a / at the end of the glob
                        if (state.globstar.path_index > 0 and state.path_index + 1 < path.len) {
                            state.glob_index = state.globstar.glob_index;
                            state.capture_index = state.globstar.capture_index;
                            state.wildcard.glob_index = state.globstar.glob_index;
                            state.wildcard.capture_index = state.globstar.capture_index;
                        } else {
                            state.wildcard.path_index = 0;
                        }
                    }

                    // If the next char is a special brace separator,
                    // skip to the end of the braces so we don't try to match it
                    if (brace_stack.length > 0 and state.glob_index < glob.len and
                        (glob[state.glob_index] == ',' or glob[state.glob_index] == '}'))
                    {
                        if (state.skipBraces(glob, captures, false) == .Invalid) {
                            // Invalid pattern!
                            return false;
                        }
                    }

                    continue;
                },
                '?' => {
                    if (state.path_index < path.len) {
                        if (!isSeparator(path[state.path_index])) {
                            state.addCharCapture(captures, path);
                            state.glob_index += 1;
                            state.path_index += Utf8.codepointLen(path[state.path_index]);
                            continue;
                        }
                    }
                },
                '[' => {
                    if (state.path_index < path.len) {
                        state.glob_index += 1;

                        const path_char_len = Utf8.codepointLen(path[state.path_index]);
                        const path_char_slice = path[state.path_index..][0..path_char_len];
                        const path_codepoint = Utf8.decode(path_char_slice);

                        var char_class_negated = false;
                        if (state.glob_index < glob.len and (glob[state.glob_index] == '^' or glob[state.glob_index] == '!')) {
                            char_class_negated = true;
                            state.glob_index += 1;
                        }

                        var first = true;
                        var is_match = false;
                        while (state.glob_index < glob.len and (first or glob[state.glob_index] != ']')) {
                            const low_len = Utf8.codepointLen(glob[state.glob_index]);
                            var low_slice = glob[state.glob_index..][0..low_len];
                            var low_index = state.glob_index;
                            var low_escaped = false;

                            // Handle escapes
                            if (low_slice.len == 1 and low_slice[0] == '\\') {
                                if (low_index + 1 >= glob.len) {
                                    // Invalid pattern!
                                    return false;
                                }
                                low_index += 1;
                                const escaped_len = Utf8.codepointLen(glob[low_index]);
                                low_slice = glob[low_index..][0..escaped_len];
                                low_escaped = true;
                            }

                            const low_codepoint = Utf8.decode(low_slice);
                            state.glob_index += low_len;
                            if (low_escaped) {
                                state.glob_index += low_slice.len;
                            }

                            // If there is a - and the following character is not ], read the range end character
                            const high_codepoint = if (state.glob_index + 1 < glob.len and
                                glob[state.glob_index] == '-' and
                                glob[state.glob_index + 1] != ']')
                            blk: {
                                state.glob_index += 1;

                                // Get high codepoint
                                const high_len = Utf8.codepointLen(glob[state.glob_index]);
                                var high_slice = glob[state.glob_index..][0..high_len];
                                var high_index = state.glob_index;
                                var high_escaped = false;

                                // Handle escapes
                                if (high_slice.len == 1 and high_slice[0] == '\\') {
                                    if (high_index + 1 >= glob.len) {
                                        // Invalid pattern!
                                        return false;
                                    }
                                    high_index += 1;
                                    const escaped_len = Utf8.codepointLen(glob[high_index]);
                                    high_slice = glob[high_index..][0..escaped_len];
                                    high_escaped = true;
                                }

                                const high_codepoint = Utf8.decode(high_slice);
                                state.glob_index += high_len;
                                if (high_escaped) {
                                    state.glob_index += high_slice.len;
                                }

                                break :blk high_codepoint;
                            } else low_codepoint;

                            if (low_codepoint <= path_codepoint and path_codepoint <= high_codepoint) {
                                is_match = true;
                            }
                            first = false;
                        }

                        if (state.glob_index >= glob.len) {
                            // Invalid pattern!
                            return false;
                        }

                        state.glob_index += 1;
                        if (is_match != char_class_negated) {
                            state.addCharCapture(captures, path);
                            state.path_index += path_char_len;
                            continue;
                        }
                    }
                },
                '{' => {
                    if (state.path_index < path.len) {
                        if (brace_stack.length >= brace_stack.stack.len) {
                            // Invalid pattern! Too many nested braces.
                            return false;
                        }

                        state.endCapture(captures);
                        state.beginCapture(captures, .{ .start = state.path_index, .end = state.path_index });
                        state = brace_stack.push(&state);
                        continue;
                    }
                },
                '}' => {
                    if (brace_stack.length > 0) {
                        // If we hit the end of the braces, we matched the last option
                        if (state.path_index > brace_stack.longest_brace_match) {
                            brace_stack.longest_brace_match = state.path_index;
                        }
                        state.glob_index += 1;
                        state = brace_stack.pop(&state, captures);
                        continue;
                    }
                },
                ',' => {
                    if (brace_stack.length > 0) {
                        // If we hit a comma, we matched one of the options
                        // still need to check the others in case there is a longer match.
                        if (state.path_index > brace_stack.longest_brace_match) {
                            brace_stack.longest_brace_match = state.path_index;
                        }
                        state.path_index = brace_stack.last().path_index;
                        state.glob_index += 1;
                        state.wildcard = Wildcard.init();
                        state.globstar = Wildcard.init();
                        continue;
                    }
                },
                else => {
                    if (state.path_index < path.len) {
                        var current_char = c;
                        // Match escaped characters as literals
                        if (!unescape(&current_char, glob, &state.glob_index)) {
                            // Invalid pattern!
                            return false;
                        }

                        // Handle UTF-8 matching
                        var is_match = false;
                        var path_char_len: usize = 1;

                        if (current_char == '/') {
                            is_match = isSeparator(path[state.path_index]);
                        } else {
                            // Single byte ASCII character
                            if (path[state.path_index] == current_char) {
                                is_match = true;
                                path_char_len = 1;
                            } else {
                                // For UTF-8 characters, compare codepoints
                                path_char_len = Utf8.codepointLen(path[state.path_index]);
                                if (state.path_index + path_char_len <= path.len) {
                                    const path_codepoint = Utf8.decode(path[state.path_index..][0..path_char_len]);
                                    if (current_char < 128) {
                                        is_match = path_codepoint == current_char;
                                    } else {
                                        const glob_char_len = Utf8.codepointLen(current_char);
                                        if (state.glob_index > 0 and state.glob_index - 1 + glob_char_len <= glob.len) {
                                            const glob_slice = glob[state.glob_index - 1 ..][0..glob_char_len];
                                            const glob_codepoint = Utf8.decode(glob_slice);
                                            is_match = path_codepoint == glob_codepoint;
                                        }
                                    }
                                }
                            }
                        }

                        if (is_match) {
                            state.endCapture(captures);
                            if (brace_stack.length > 0 and state.glob_index > 0 and glob[state.glob_index - 1] == '}') {
                                brace_stack.longest_brace_match = state.path_index;
                                state = brace_stack.pop(&state, captures);
                            }
                            state.glob_index += 1;
                            state.path_index += path_char_len;

                            // If this is not a separator, lock in the previous globstar
                            if (current_char != '/') {
                                state.globstar.path_index = 0;
                            }
                            continue;
                        }
                    }
                },
            }
        }

        // If we didn't match, restore state to the previous star pattern
        if (state.wildcard.path_index > 0 and state.wildcard.path_index <= path.len) {
            state.backtrack();
            continue;
        }

        if (brace_stack.length > 0) {
            // If in braces, find the next option and reset path to index where we saw the '{'
            const brace_state = state.skipBraces(glob, captures, true);
            switch (brace_state) {
                .Invalid => return false,
                .Comma => {
                    state.path_index = brace_stack.last().path_index;
                    continue;
                },
                .EndBrace => {},
            }

            // Hit the end. Pop the stack.
            // If we matched a previous option, use that.
            if (brace_stack.longest_brace_match > 0) {
                state = brace_stack.pop(&state, captures);
                continue;
            } else {
                // Didn't match. Restore state, and check if we need to jump back to a star pattern.
                const last = brace_stack.last().*;
                state = last;
                brace_stack.length -= 1;
                if (captures) |c| {
                    c.resize(state.capture_index) catch {};
                }
                if (state.wildcard.path_index > 0 and state.wildcard.path_index <= path.len) {
                    state.backtrack();
                    continue;
                }
            }
        }

        return negated;
    }

    if (brace_stack.length > 0 and state.glob_index > 0 and glob[state.glob_index - 1] == '}') {
        brace_stack.longest_brace_match = state.path_index;
        _ = brace_stack.pop(&state, captures);
    }

    return !negated;
}
