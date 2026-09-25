import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/media/video_thumbnail_service.dart';

/// The picture on a work's card.
///
/// Three sources, in order, and the third is the caller's own placeholder:
///
/// 1. [imageUrl] — a cover the backend sent. Used as-is.
/// 2. [videoUrl] — a frame pulled out of the video by
///    [VideoThumbnailService]. This is the normal case for a **video** work,
///    which the backend sends with `image: null`.
/// 3. [placeholder] — the card's existing grey panel, while the frame is being
///    produced and whenever it cannot be.
///
/// It is deliberately a **drop-in for the image widget it replaces**: same box,
/// same `BoxFit`, same fallback. Nothing about the layout changes, so a card that
/// used to show a placeholder now shows a frame in the same place.
class VideoThumbnailView extends StatefulWidget {
  /// A cover from the backend, if there is one. Wins when non-empty.
  final String imageUrl;

  /// The video to take a frame from when there is no cover. Ignored if empty.
  final String videoUrl;

  /// Shown while loading and when no picture can be produced.
  final Widget placeholder;

  /// Builds what is shown **only** while a cover from [imageUrl] is still
  /// downloading, given the download progress so far (null when unknown).
  ///
  /// Defaults to [placeholder]. Kept separate so a card that already had a
  /// download progress indicator keeps it exactly, while a frame being extracted
  /// from the video shows the placeholder rather than a spinner.
  final Widget Function(BuildContext context, ImageChunkEvent? progress)? loading;

  final BoxFit fit;
  final FilterQuality filterQuality;

  const VideoThumbnailView({
    super.key,
    required this.imageUrl,
    required this.videoUrl,
    required this.placeholder,
    this.loading,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  State<VideoThumbnailView> createState() => _VideoThumbnailViewState();
}

class _VideoThumbnailViewState extends State<VideoThumbnailView> {
  Uint8List? _frame;

  /// Set once the extraction has been asked for, so the widget does not fire a
  /// new request on every rebuild.
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _maybeExtract();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A recycled grid cell can be handed a different work.
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.imageUrl != widget.imageUrl) {
      _frame = null;
      _requested = false;
      _maybeExtract();
    }
  }

  void _maybeExtract() {
    if (_requested) return;

    // A real cover is already the answer — do not decode a frame for nothing.
    if (widget.imageUrl.trim().isNotEmpty) return;
    if (widget.videoUrl.trim().isEmpty) return;

    _requested = true;

    VideoThumbnailService.instance.frame(widget.videoUrl).then((
      Uint8List? bytes,
    ) {
      if (!mounted || bytes == null) return;
      setState(() {
        _frame = bytes;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.imageUrl.trim();

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? progress,
        ) {
          // No progress event means the frame is already decoded.
          if (progress == null) return child;

          final Widget Function(BuildContext, ImageChunkEvent?)? build =
              widget.loading;
          return build == null
              ? widget.placeholder
              : build(context, progress);
        },
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    }

    final Uint8List? frame = _frame;

    if (frame != null) {
      return Image.memory(
        frame,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        // The bytes came from the platform thumbnailer, so a decode failure is
        // all but impossible — but a card must never throw either way.
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    }

    return widget.placeholder;
  }
}
