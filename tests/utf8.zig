const std = @import("std");

const utf8 = @import("zut").utf8;

test "utf8.charLength" {
    const testing = std.testing;

    // Empty input
    try testing.expectEqual(0, utf8.charLength(""));

    // ASCII characters
    try testing.expectEqual(5, utf8.charLength("hello"));
    try testing.expectEqual(10, utf8.charLength("1234567890"));
    try testing.expectEqual(10, utf8.charLength("!@#$%^&*()"));

    // Multibyte UTF-8 characters
    try testing.expectEqual(1, utf8.charLength("ñ"));
    try testing.expectEqual(2, utf8.charLength("你好"));
    try testing.expectEqual(1, utf8.charLength("🌍"));
    try testing.expectEqual(1, utf8.charLength("🇺🇸")); // Regional indicator pair (flags)

    // Mixed ASCII and Unicode
    try testing.expectEqual(10, utf8.charLength("Hello, 世界!"));
    try testing.expectEqual(6, utf8.charLength("Café 🍩"));

    // Malformed UTF-8 sequences
    try testing.expectError(error.TruncatedInput, utf8.charLength(&[_]u8{0xC3})); // Incomplete 2-byte sequence
    try testing.expectError(error.TruncatedInput, utf8.charLength(&[_]u8{ 0xE2, 0x82 })); // Incomplete 3-byte sequence
    try testing.expectError(error.TruncatedInput, utf8.charLength(&[_]u8{ 0xF0, 0x9F })); // Incomplete 4-byte sequence

    // Overlong encoding (invalid UTF-8)
    try testing.expectError(error.Utf8OverlongEncoding, utf8.charLength(&[_]u8{ 0xC0, 0xAF }));
    try testing.expectError(error.Utf8OverlongEncoding, utf8.charLength(&[_]u8{ 0xE0, 0x80, 0x80 }));

    // ANSI escape sequences
    try testing.expectEqual(3, utf8.charLength("\x1b[31mRed\x1b[0m")); // ANSI color code should be ignored
    try testing.expectEqual(5, utf8.charLength("\x1b[32mGreen\x1b[0m"));
    try testing.expectEqual(9, utf8.charLength("\x1b[1;34mBold Blue\x1b[0m"));
    try testing.expectEqual(10, utf8.charLength("Normal\x1b[1mBold\x1b[0m"));

    // Edge cases with ANSI codes
    try testing.expectEqual(0, utf8.charLength("\x1b[m")); // Minimal valid ANSI sequence
    try testing.expectEqual(0, utf8.charLength("\x1b[999m")); // Large but valid ANSI sequence
    try testing.expectEqual(0, utf8.charLength("\x1b[")); // Incomplete ANSI sequence
    try testing.expectEqual(0, utf8.charLength("\x1b[3")); // Truncated escape sequence

    // Unicode edge cases
    try testing.expectEqual(1, utf8.charLength("𝄞")); // Musical symbol G-clef (U+1D11E)
    try testing.expectEqual(1, utf8.charLength("𐍈")); // Gothic letter hwair (U+10348)
    try testing.expectEqual(5, utf8.charLength("😀😁😂🤣😃")); // Emojis
    try testing.expectEqual(1, utf8.charLength("👨‍👩‍👧‍👦")); // Family emoji (single grapheme)
    try testing.expectEqual(4, utf8.charLength("🏼🏽🏾🏿")); // Skin tone modifiers

    // Invalid UTF-8 characters should not be counted
    try testing.expectEqual(0, utf8.charLength(&[_]u8{0x80})); // Invalid start byte
    try testing.expectEqual(0, utf8.charLength(&[_]u8{0xFE})); // Invalid byte
    try testing.expectEqual(0, utf8.charLength(&[_]u8{0xFF})); // Invalid byte

    // Valid Unicode surrogate pair handling (wrong usage in UTF-8 but valid as UTF-16 surrogates)
    try testing.expectEqual(2, utf8.charLength("𐍈𐍈")); // Two instances of U+10348

    // Combining diacritical marks
    try testing.expectEqual(2, utf8.charLength("é")); // 'e' + acute accent
    try testing.expectEqual(4, utf8.charLength("é́́")); // Multiple diacritics on 'e'

    // Special edge case with combining marks after ASCII characters
    try testing.expectEqual(2, utf8.charLength("á")); // 'a' + accent mark (combining)

    // Mixed malformed input (ASCII and invalid)
    try testing.expectError(error.Utf8ExpectedContinuation, utf8.charLength(&[_]u8{ 0x61, 0xC3, 0x28 })); // 'a' + partial UTF-8

    // Input with multiple invalid sequences
    try testing.expectError(error.Utf8ExpectedContinuation, utf8.charLength(&[_]u8{ 0x80, 0xC3, 0xF0, 0xFF })); // Multiple invalid bytes mixed

    // Valid, large-length string with a mix of UTF-8 characters
    try testing.expectEqual(500, utf8.charLength("𐍈" ** 500)); // Large string of valid Unicode

    // Check for large code points (invalid if encoded incorrectly)
    try testing.expectError(error.Utf8CodepointTooLarge, utf8.charLength(&[_]u8{ 0xF4, 0x90, 0x80, 0x80 })); // Invalid 4-byte code point (too large)
}
