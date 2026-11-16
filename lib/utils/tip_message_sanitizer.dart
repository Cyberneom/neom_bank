/// Pure-Dart sanitization and bounds helpers for [TipController] and [TipFirestore].
class TipMessageSanitizer {
  const TipMessageSanitizer._();

  static const int maxTipMessageLength = 500;
  static const int maxTipQueryLimit = 100;

  static final RegExp _gemmaThoughtClosedPattern = RegExp(
    r'<\|(?:channel|turn)\s*>\s*thought\b[\s\S]*?<(?:channel|turn)\|>'
    r'|<\|tool_call\s*>[\s\S]*?<tool_call\|>',
    caseSensitive: false,
  );
  static final RegExp _gemmaThoughtUnclosedPattern = RegExp(
    r'<\|(?:channel|turn)\s*>\s*thought\b[\s\S]*$'
    r'|<\|tool_call\s*>[\s\S]*$',
    caseSensitive: false,
  );
  static final RegExp _internalTagBlockPattern = RegExp(
    r'<\s*(think(?:ing)?|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*?<\s*/\s*\1\s*>',
    caseSensitive: false,
  );
  static final RegExp _unclosedInternalTagTailPattern = RegExp(
    r'<\s*(?:think(?:ing)?|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*$',
    caseSensitive: false,
  );
  static final RegExp _orphanInternalTagPattern = RegExp(
    r'(?:<\s*/?\s*(?:think(?:ing)?|thought|memory_recall|auto_memory|system_context)\b[^>]*>|<\|/?(?:channel|turn|tool_call|eot_id|im_start|im_end)\|?>|<(?:channel|turn|tool_call|eot)\|>|<\|?(?:turn|tool_call)\b[^>]*>)',
    caseSensitive: false,
  );
  static final RegExp _pairedBiochipBlockPattern = RegExp(
    r'\[\s*(BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\s*\](?:(?!\[\s*\1\s*\])[\s\S])*?\[\s*/\s*\1\s*\]',
    caseSensitive: false,
  );
  static final RegExp _biochipPattern = RegExp(
    r'\[\s*/?\s*(?:BIOCHIP(?:\s*:[^\]]*)?|MEMORY_RECALL(?:\s*:[^\]]*)?|AUTO_MEMORY(?:\s*:[^\]]*)?|SYSTEM_CONTEXT(?:\s*:[^\]]*)?)\s*\]',
    caseSensitive: false,
  );
  static final RegExp _closingContentBoundaryPattern = RegExp(
    r'<\s*/\s*content\s*>',
    caseSensitive: false,
  );
  static final RegExp _unsafeTipControls = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u061C\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
  );

  /// Strips internal reasoning tags (`<think>`, `<memory_recall>`, `<auto_memory>`,
  /// `<system_context>`, Gemma-4 `<|channel>thought...<channel|>` / `<|turn>thought...<turn|>`,
  /// `[BIOCHIP: ...]`), neutralizes `</content>` boundary breakouts, strips Trojan
  /// Source Bidi overrides and C0/C1 control characters, and truncates cleanly
  /// on Unicode rune boundaries (never splitting UTF-16 surrogate pairs).
  static String? sanitize(String? raw) {
    if (raw == null) return null;
    final cleaned = raw
        .replaceAll(_gemmaThoughtClosedPattern, '')
        .replaceAll(_gemmaThoughtUnclosedPattern, '')
        .replaceAll(_internalTagBlockPattern, '')
        .replaceAll(_unclosedInternalTagTailPattern, '')
        .replaceAll(_orphanInternalTagPattern, '')
        .replaceAll(_pairedBiochipBlockPattern, '')
        .replaceAll(_biochipPattern, '')
        .replaceAll(_closingContentBoundaryPattern, '[content_end]')
        .replaceAll('\u2028', '\n')
        .replaceAll('\u2029', '\n')
        .replaceAll(_unsafeTipControls, '')
        .trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.runes.length > maxTipMessageLength) {
      return String.fromCharCodes(cleaned.runes.take(maxTipMessageLength));
    }
    return cleaned;
  }

  /// Clamps requested query [limit] to `[1 .. maxLimit]`, guarding JS `Infinity`/`NaN`.
  static int clampLimit(int limit, {int maxLimit = maxTipQueryLimit}) {
    if (!maxLimit.isFinite || maxLimit < 1) return 1;
    if (!limit.isFinite) return 1;
    return limit.clamp(1, maxLimit);
  }
}
