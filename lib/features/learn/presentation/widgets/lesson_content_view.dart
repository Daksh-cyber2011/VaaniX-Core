/// Lesson Content View — Minimal Markdown Renderer
///
/// Renders the markdown-like lesson content strings (see [Lesson.content]
/// docstring for format spec) into Flutter widgets.
///
/// Supported block types:
/// - `# Heading` → H1 heading (headlineSmall, bold, primary color)
/// - `## Subheading` → H2 heading (titleLarge, bold)
/// - `### Sub-subheading` → H3 heading (titleMedium, bold)
/// - Plain text paragraphs → body text (justified)
/// - `- Bullet item` → bulleted list row
/// - `> Quote text` → blockquote (left accent border, italic)
/// - `| Col1 | Col2 | Col3 |` → 3-column table (with `|---|---|---|` separator)
///
/// Devanagari text (Unicode range \u0900-\u097F) is rendered with
/// [AppTextStyles.sanskritBody] for proper font support.

import 'package:flutter/material.dart';

import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';

class LessonContentView extends StatelessWidget {
  const LessonContentView({
    super.key,
    required this.content,
  });

  /// The markdown-like content string to render.
  final String content;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(content);
    return blocks.isEmpty
        ? const Center(child: Text('This lesson has no content yet.'))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: blocks,
            ),
          );
  }

  /// Parse the markdown-like string into a list of Flutter widgets.
  ///
  /// Line-by-line state machine: groups consecutive bullet lines into a
  /// Column, accumulates table rows into a Table widget, and treats
  /// everything else as standalone paragraphs/headings/quotes.
  List<Widget> _parse(String source) {
    final lines = source.split('\n');
    final blocks = <Widget>[];

    // Buffer for consecutive bullet items (so they render as one list).
    final bulletBuffer = <String>[];

    // Buffer for table rows (header + data rows).
    final tableBuffer = <List<String>>[];

    void flushBullets() {
      if (bulletBuffer.isEmpty) return;
      blocks.add(_BulletList(items: List.unmodifiable(bulletBuffer)));
      blocks.add(const SizedBox(height: 12));
      bulletBuffer.clear();
    }

    void flushTable() {
      if (tableBuffer.isEmpty) return;
      blocks.add(_ContentTable(rows: List.unmodifiable(tableBuffer)));
      blocks.add(const SizedBox(height: 16));
      tableBuffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      // Skip empty lines — they separate blocks.
      if (line.trim().isEmpty) {
        flushBullets();
        // Don't flush tables on empty lines — tables have their own
        // internal structure and the separator row matters.
        continue;
      }

      // Heading: # H1, ## H2, ### H3
      if (line.startsWith('### ')) {
        flushBullets();
        flushTable();
        blocks.add(_Heading(text: line.substring(4).trim(), level: 3));
        blocks.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('## ')) {
        flushBullets();
        flushTable();
        blocks.add(_Heading(text: line.substring(3).trim(), level: 2));
        blocks.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('# ')) {
        flushBullets();
        flushTable();
        blocks.add(_Heading(text: line.substring(2).trim(), level: 1));
        blocks.add(const SizedBox(height: 14));
        continue;
      }

      // Bullet: - item
      if (line.startsWith('- ')) {
        flushTable();
        bulletBuffer.add(line.substring(2).trim());
        continue;
      }

      // Blockquote: > text
      if (line.startsWith('> ')) {
        flushBullets();
        flushTable();
        blocks.add(_Blockquote(text: line.substring(2).trim()));
        blocks.add(const SizedBox(height: 14));
        continue;
      }

      // Table row: | col1 | col2 | col3 |
      if (line.startsWith('|') && line.endsWith('|')) {
        flushBullets();
        // Skip the separator row: |---|---|---|
        if (line.contains('---')) continue;
        final cells = line
            .split('|')
            .where((c) => c.trim().isNotEmpty)
            .map((c) => c.trim())
            .toList();
        tableBuffer.add(cells);
        continue;
      }

      // Default: paragraph
      flushBullets();
      flushTable();
      blocks.add(_Paragraph(text: line.trim()));
      blocks.add(const SizedBox(height: 10));
    }

    // Flush any remaining buffers.
    flushBullets();
    flushTable();

    return blocks;
  }
}

// ─── Block widgets ───────────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.level});

  final String text;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: switch (level) {
        1 => AppTextStyles.headlineSmall(color: AppColors.primary),
        2 => AppTextStyles.titleLarge(),
        _ => AppTextStyles.titleMedium(),
      },
      textAlign: TextAlign.left,
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final hasDevanagari = _containsDevanagari(text);
    return Text(
      text,
      style: hasDevanagari
          ? AppTextStyles.sanskritBody()
          : AppTextStyles.bodyMedium(),
      textAlign: TextAlign.left,
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final hasDevanagari = _containsDevanagari(item);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: hasDevanagari
                      ? AppTextStyles.sanskritBody()
                      : AppTextStyles.bodyMedium(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Blockquote extends StatelessWidget {
  const _Blockquote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final hasDevanagari = _containsDevanagari(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: (hasDevanagari
                ? AppTextStyles.sanskritBody()
                : AppTextStyles.bodyMedium())
            .copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _ContentTable extends StatelessWidget {
  const _ContentTable({required this.rows});

  /// First row = header, remaining rows = data.
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final headerRow = rows.first;
    final dataRows = rows.skip(1).toList();
    final columnCount = headerRow.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: {
          for (var i = 0; i < columnCount; i++)
            i: const FlexColumnWidth(1),
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: AppColors.borderLight.withValues(alpha: 0.5),
            width: 1,
          ),
          verticalInside: BorderSide(
            color: AppColors.borderLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            children: [
              for (final cell in headerRow)
                _TableCell(text: cell, isHeader: true),
            ],
          ),
          // Data rows
          for (final row in dataRows)
            TableRow(
              children: [
                for (var i = 0; i < columnCount; i++)
                  _TableCell(text: i < row.length ? row[i] : ''),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.text, this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final hasDevanagari = _containsDevanagari(text);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: isHeader
            ? AppTextStyles.labelMedium(color: AppColors.primary)
            : (hasDevanagari
                ? AppTextStyles.sanskritBody()
                : AppTextStyles.bodySmall()),
        textAlign: TextAlign.left,
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Returns true if the string contains any Devanagari character
/// (Unicode range U+0900–U+097F).
bool _containsDevanagari(String text) {
  for (final codeUnit in text.codeUnits) {
    if (codeUnit >= 0x0900 && codeUnit <= 0x097F) return true;
  }
  return false;
}
