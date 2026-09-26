import 'package:flutter/material.dart';

/// Decodes a photo straight to the size it is actually drawn at.
///
/// A camera photo is typically a few thousand pixels per side. Decoded at
/// full size and then scaled down into a 48px avatar it still occupies
/// megabytes in the image cache — and a People grid full of them is the
/// quickest way to an OutOfMemoryError on a low-end phone. Passing
/// [Image.file]'s `cacheWidth` makes the decoder downsample first, so only
/// the pixels that get painted are ever held in memory.
int cacheWidthFor(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context)).round();

/// Pairing for an `Image.file`/`Image.asset` that is being shown as an avatar
/// or thumbnail: decode to size, and skip the expensive high-quality filter
/// (which is a no-op visually when downscaling a photo this far).
({int cacheWidth, FilterQuality filterQuality}) thumbnailDecode(
  BuildContext context,
  double logicalSize,
) =>
    (
      cacheWidth: cacheWidthFor(context, logicalSize),
      filterQuality: FilterQuality.medium,
    );
