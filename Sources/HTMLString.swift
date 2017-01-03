/**
 * ==---------------------------------------------------------------------------------==
 *
 *  File            :   HTMLString.swift
 *  Project         :   HTMLString
 *  Author          :   Alexis Aubry Radanovic
 *
 *  License         :   The MIT License (MIT)
 *
 * ==---------------------------------------------------------------------------------==
 *
 *	The MIT License (MIT)
 *	Copyright (c) 2016-2017 Alexis Aubry Radanovic
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy of
 *	this software and associated documentation files (the "Software"), to deal in
 *	the Software without restriction, including without limitation the rights to
 *	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 *	the Software, and to permit persons to whom the Software is furnished to do so,
 *	subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in all
 *	copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 *	FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 *	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 *	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 *	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ==---------------------------------------------------------------------------------==
 */

import Foundation

// MARK: Escaping

public extension String {

    ///
    /// A string where internal characters that need escaping for HTML are escaped.
    ///
    /// Only special Unicode characters will be escaped.
    ///
    /// For example, `"&"` become `"\&amp;"`.
    ///

    public var escapingForUnicodeHTML: String {
        return escapeHTML(isEncodingUnicode: true)
    }

    ///
    /// A string where internal characters that need escaping for HTML are escaped.
    ///
    /// For instance, '&' becomes '\&amp;' and '🙃' becomes '\&#x1F643;'.
    ///
    /// All non-mapped characters (unicode that don't have a `&keyword;` mapping) will be converted
    /// to the appropriate &#xxx; value.
    ///
    /// If your webpage is unicode encoded (UTF16 or UTF8) use `escapingForHTML` instead as it is
    /// faster, and produces less bloated and more readable HTML (as long as you are using a unicode
    /// compliant HTML reader).
    ///

    public var escapingForASCIIHTML: String {
        return escapeHTML(isEncodingUnicode: false)
    }

    private func escapeHTML(isEncodingUnicode: Bool) -> String {

        return self.characters.reduce(String()) {

            let character = String($1)

            // Ignore alphanumerical characters to improve performance.
            guard character < "\u{30}" || character > "\u{7a}" else {
                return $0 + character
            }

            let escaped = isEncodingUnicode ? character._performUnicodeEscaping() : character._performASCIIEscaping()
            return $0 + escaped

        }

    }

    private func _performASCIIEscaping() -> String {

        guard let escapeSequence = HTMLTables.escapingTable[self] else {
            return unicodeScalars.reduce(String()) { $0 + $1.escapingForASCII }
        }

        return escapeSequence

    }

    private func _performUnicodeEscaping() -> String {
        return unicodeScalars.reduce(String()) { $0 + $1.escapingIfNeeded }
    }

}

// MARK: - Unescaping

extension String {

    ///
    /// A string where internal characters that are escaped for HTML are unescaped.
    ///
    /// For example, `&amp;` becomes `&`. Handles `&#32;` and `&#x32;` cases as well.
    ///

    public var unescapingFromHTML: String {

        guard self.contains("&") else {
            return self
        }

        var unescapedString = self
        var searchRange = unescapedString.startIndex ..< unescapedString.endIndex

        while let delimiterRange = unescapedString.range(of: "&", range: searchRange) {

            let semicolonSearchRange = delimiterRange.upperBound ..< unescapedString.endIndex

            guard let semicolonRange = unescapedString.range(of: ";", range: semicolonSearchRange) else {
                searchRange = delimiterRange.upperBound ..< unescapedString.endIndex
                continue
            }

            let escapeSequenceBounds = delimiterRange.lowerBound ..< semicolonRange.upperBound

            let escapableContentRange = delimiterRange.upperBound ..< semicolonRange.lowerBound
            let escapableContent = unescapedString.substring(with: escapableContentRange)

            let replacementString: String

            if escapableContent[escapableContent.startIndex] == "#" {

                guard let unescapedNumericalSequence = unescaped(numericalSequence: escapableContent) else {
                    searchRange = escapeSequenceBounds.upperBound ..< unescapedString.endIndex
                    continue
                }

                replacementString = unescapedNumericalSequence

            } else {

                guard let unescapedCharacter = HTMLTables.unescapingTable[escapableContent] else {
                    searchRange = escapeSequenceBounds.upperBound ..< unescapedString.endIndex
                    continue
                }

                replacementString = unescapedCharacter

            }

            unescapedString.replaceSubrange(escapeSequenceBounds, with: replacementString)
            searchRange = delimiterRange.upperBound ..< unescapedString.endIndex

        }

        return unescapedString

    }

    ///
    /// Unescapes a numerical escape sequence.
    ///
    /// Numerical sequences can be either decimal (`&#45;`) or hexadecimal (`&#xc1`).
    ///
    /// - parameter numericalSequence: The sequence to escape. It must not contain the `&` prefix of the `;` suffix.
    ///
    /// - returns: The unescaped version of the sequence, or `nil` if unescaping failed.
    ///

    fileprivate func unescaped(numericalSequence: String) -> String? {

        let secondCharacter = numericalSequence[numericalSequence.index(after: numericalSequence.startIndex)]
        let isHexadecimal = (secondCharacter == "X" || secondCharacter == "x")

        let numberStartIndexOffset = isHexadecimal ? 2 : 1
        let numberStartIndex = numericalSequence.index(numericalSequence.startIndex, offsetBy: numberStartIndexOffset)

        let numberStringRange = numberStartIndex ..< numericalSequence.endIndex
        let numberString = numericalSequence.substring(with: numberStringRange)

        var codePoint = UInt32()

        if isHexadecimal {

            let scanner = Scanner(string: numberString)

            guard let _codePoint = scanner.scanHexInt() else {
                return nil
            }

            codePoint = _codePoint

        } else {

            guard let _codePoint = UInt32(numberString) else {
                return nil
            }

            codePoint = _codePoint

        }

        guard let scalar = UnicodeScalar(codePoint) else {
            return nil
        }

        return String(Character(scalar))

    }

}
