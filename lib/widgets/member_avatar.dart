import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/const/app_dimensions.dart';

/// Circular avatar for a trip member.
///
/// Members are identified by name (a [Trip] stores names, not `Person`
/// references), so this takes the name and an optional photo path and falls
/// back to coloured initials. The colour is derived from the name, which keeps
/// a member recognisable across screens without storing anything extra.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = AppDimensions.avatarSizeStandard,
    this.borderColor,
  });

  final String name;
  final String? photoPath;
  final double size;

  /// Typically the surrounding surface colour, so overlapping avatars in a
  /// stack read as separate circles.
  final Color? borderColor;

  static const List<Color> _palette = [
    Color(0xFF6C63FF),
    Color(0xFF047857),
    Color(0xFFF5A524),
    Color(0xFFD32E2E),
    Color(0xFF0284C7),
    Color(0xFF9333EA),
    Color(0xFFDB2777),
    Color(0xFF0D9488),
  ];

  static Color colorFor(String name) {
    if (name.isEmpty) return _palette.first;
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final single = parts.first;
      return single.substring(0, single.length > 1 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = colorFor(name);
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.14),
        border: Border.all(
          color: borderColor ?? accent.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? _photo(photoPath!)
          : Center(
              child: Text(
                initialsFor(name),
                style: GoogleFonts.dmSans(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
    );
  }

  Widget _photo(String path) {
    final isAsset = path.startsWith('assets/');
    return isAsset
        ? Image.asset(
            path,
            fit: BoxFit.cover,
            // Decoding straight to the size actually drawn keeps a full-size
            // photo from being held in the image cache at avatar resolution.
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (context, error, stack) => Center(
              child: Text(
                initialsFor(name),
                style: GoogleFonts.dmSans(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: colorFor(name),
                ),
              ),
            ),
          );
  }
}
