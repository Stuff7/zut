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

pub fn esc(comptime v: []const u8) []const u8 {
    return "\x1b[" ++ v ++ "m";
}

pub fn clr(comptime id: []const u8) []const u8 {
    return "\x1b[38;5;" ++ id ++ "m";
}
