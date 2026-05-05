const std = @import("std");

pub fn isSpace(b: u8) bool {
    return b == ' ' or b == '\t' or b == '\n' or b == '\r';
}

pub fn isPrintable(code_point: u32) bool {
    return (code_point >= 0x20 and code_point != 0x7F) and
        (code_point != 0x200B);
}

/// Returns the number of characters in a UTF-8 encoded buffer.
/// Skips over ANSI escape sequences and handles the following edge cases:
/// - Multibyte UTF-8 characters (like emoji or non-ASCII symbols)
/// - Regional flags (counted as one character)
/// - Zero Width Joiner (ZWJ) sequences (do not count as characters)
/// - Combining diacritics (counted with their base character)
/// - Malformed UTF-8 sequences (returns `error.TruncatedInput`)
pub fn charLength(buf: []const u8) !usize {
    var char_len: usize = 0;
    var i: usize = 0;
    const len = buf.len;
    var prev_was_regional = false;
    var in_zwj_sequence = false;

    while (i < len) {
        if (buf[i] == 0x1b) {
            if (i + 1 < len) i += 1;

            if (buf[i] != '[') {
                continue;
            }

            while (i < len and buf[i] != 'm') {
                i += 1;
            }

            i += 1;
        } else {
            const clen = std.unicode.utf8ByteSequenceLength(buf[i]) catch {
                i += 1;
                continue;
            };

            if (i + clen > buf.len) {
                return error.TruncatedInput;
            }

            const c = if (clen == 1) buf[i] else try std.unicode.utf8Decode(buf[i .. i + clen]);
            const is_regional = c >= 0x1F1E6 and c <= 0x1F1FF;
            const is_zwj = c == 0x200D;

            if (isPrintable(c)) {
                if (is_zwj) {
                    in_zwj_sequence = true;
                } else if (is_regional and prev_was_regional) {
                    prev_was_regional = false;
                } else {
                    if (!in_zwj_sequence) {
                        char_len += 1;
                    }
                    prev_was_regional = is_regional;
                    in_zwj_sequence = false;
                }
            } else {
                prev_was_regional = false;
                in_zwj_sequence = false;
            }

            i += clen;
        }
    }

    return char_len;
}

pub fn decodeCodepoint(buf: []const u8) !u21 {
    if (buf.len != try std.unicode.utf8ByteSequenceLength(buf[0])) {
        return error.Utf8InvalidStartByte;
    }

    return switch (buf.len) {
        1 => buf[0],
        2 => try std.unicode.utf8Decode2(buf[0..2].*),
        3 => try std.unicode.utf8Decode3(buf[0..3].*),
        4 => try std.unicode.utf8Decode4(buf[0..4].*),
        else => unreachable,
    };
}

/// Given a codepoint returns a **bool** indicating if the character is
/// *visually* wide based on the **Unicode East Asian Width** table
pub fn isWideChar(codepoint: u21) bool {
    // zig fmt: off
    return (codepoint >= 0x1100  and codepoint <= 0x115F)  or // Hangul Jamo
           (codepoint >= 0x2E80  and codepoint <= 0xA4CF)  or // CJK Radicals, Kanji, etc.
           (codepoint >= 0xAC00  and codepoint <= 0xD7A3)  or // Hangul Syllables
           (codepoint >= 0xF900  and codepoint <= 0xFAFF)  or // CJK Compatibility Ideographs
           (codepoint >= 0xFE10  and codepoint <= 0xFE19)  or // Vertical Punctuation
           (codepoint >= 0xFE30  and codepoint <= 0xFE6F)  or // CJK Compatibility Forms
           (codepoint >= 0xFF00  and codepoint <= 0xFF60)  or // Fullwidth ASCII Variants
           (codepoint >= 0xFFE0  and codepoint <= 0xFFE6)  or // Fullwidth Symbols
           (codepoint >= 0x1F300 and codepoint <= 0x1F64F) or // Emojis
           (codepoint >= 0x1F900 and codepoint <= 0x1F9FF);   // More Emojis
    // zig fmt: on
}

/// Given a **utf-8** string it returns it's *visual* length based on the **Unicode East Asian Width** of each character
pub fn visualStringLength(str: []const u8) !usize {
    var it = (try std.unicode.Utf8View.init(str)).iterator();
    var charlen: usize = 0;

    while (it.nextCodepoint()) |c| {
        charlen += if (isWideChar(c)) 2 else 1;
    }

    return charlen;
}

/// Given a **utf-8** character slice it returns it's *visual* length based on the **Unicode East Asian Width**
pub fn charWidthFromSlice(slice: []u8) !usize {
    const codepoint = try decodeCodepoint(slice);
    return if (isWideChar(codepoint)) 2 else 1;
}

pub fn ansi(comptime txt: []const u8, comptime styles: []const u8) []const u8 {
    return "\x1b[" ++ styles ++ "m" ++ txt ++ "\x1b[0m";
}

test "utf8.charLength" {
    const testing = std.testing;

    // Empty input
    try testing.expectEqual(0, charLength(""));

    // ASCII characters
    try testing.expectEqual(5, charLength("hello"));
    try testing.expectEqual(10, charLength("1234567890"));
    try testing.expectEqual(10, charLength("!@#$%^&*()"));

    // Multibyte UTF-8 characters
    try testing.expectEqual(1, charLength("ñ"));
    try testing.expectEqual(2, charLength("你好"));
    try testing.expectEqual(1, charLength("🌍"));
    try testing.expectEqual(1, charLength("🇺🇸")); // Regional indicator pair (flags)

    // Mixed ASCII and Unicode
    try testing.expectEqual(10, charLength("Hello, 世界!"));
    try testing.expectEqual(6, charLength("Café 🍩"));

    // Malformed UTF-8 sequences
    try testing.expectError(error.TruncatedInput, charLength(&[_]u8{0xC3})); // Incomplete 2-byte sequence
    try testing.expectError(error.TruncatedInput, charLength(&[_]u8{ 0xE2, 0x82 })); // Incomplete 3-byte sequence
    try testing.expectError(error.TruncatedInput, charLength(&[_]u8{ 0xF0, 0x9F })); // Incomplete 4-byte sequence

    // Overlong encoding (invalid UTF-8)
    try testing.expectError(error.Utf8OverlongEncoding, charLength(&[_]u8{ 0xC0, 0xAF }));
    try testing.expectError(error.Utf8OverlongEncoding, charLength(&[_]u8{ 0xE0, 0x80, 0x80 }));

    // ANSI escape sequences
    try testing.expectEqual(3, charLength("\x1b[31mRed\x1b[0m")); // ANSI color code should be ignored
    try testing.expectEqual(5, charLength("\x1b[32mGreen\x1b[0m"));
    try testing.expectEqual(9, charLength("\x1b[1;34mBold Blue\x1b[0m"));
    try testing.expectEqual(10, charLength("Normal\x1b[1mBold\x1b[0m"));

    // Edge cases with ANSI codes
    try testing.expectEqual(0, charLength("\x1b[m")); // Minimal valid ANSI sequence
    try testing.expectEqual(0, charLength("\x1b[999m")); // Large but valid ANSI sequence
    try testing.expectEqual(0, charLength("\x1b[")); // Incomplete ANSI sequence
    try testing.expectEqual(0, charLength("\x1b[3")); // Truncated escape sequence

    // Unicode edge cases
    try testing.expectEqual(1, charLength("𝄞")); // Musical symbol G-clef (U+1D11E)
    try testing.expectEqual(1, charLength("𐍈")); // Gothic letter hwair (U+10348)
    try testing.expectEqual(5, charLength("😀😁😂🤣😃")); // Emojis
    try testing.expectEqual(1, charLength("👨‍👩‍👧‍👦")); // Family emoji (single grapheme)
    try testing.expectEqual(4, charLength("🏼🏽🏾🏿")); // Skin tone modifiers

    // Invalid UTF-8 characters should not be counted
    try testing.expectEqual(0, charLength(&[_]u8{0x80})); // Invalid start byte
    try testing.expectEqual(0, charLength(&[_]u8{0xFE})); // Invalid byte
    try testing.expectEqual(0, charLength(&[_]u8{0xFF})); // Invalid byte

    // Valid Unicode surrogate pair handling (wrong usage in UTF-8 but valid as UTF-16 surrogates)
    try testing.expectEqual(2, charLength("𐍈𐍈")); // Two instances of U+10348

    // Combining diacritical marks
    try testing.expectEqual(2, charLength("é")); // 'e' + acute accent
    try testing.expectEqual(4, charLength("é́́")); // Multiple diacritics on 'e'

    // Special edge case with combining marks after ASCII characters
    try testing.expectEqual(2, charLength("á")); // 'a' + accent mark (combining)

    // Mixed malformed input (ASCII and invalid)
    try testing.expectError(error.Utf8ExpectedContinuation, charLength(&[_]u8{ 0x61, 0xC3, 0x28 })); // 'a' + partial UTF-8

    // Input with multiple invalid sequences
    try testing.expectError(error.Utf8ExpectedContinuation, charLength(&[_]u8{ 0x80, 0xC3, 0xF0, 0xFF })); // Multiple invalid bytes mixed

    // Valid, large-length string with a mix of UTF-8 characters
    try testing.expectEqual(500, charLength("𐍈"**500)); // Large string of valid Unicode

    // Check for large code points (invalid if encoded incorrectly)
    try testing.expectError(error.Utf8CodepointTooLarge, charLength(&[_]u8{ 0xF4, 0x90, 0x80, 0x80 })); // Invalid 4-byte code point (too large)
}
