import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/settings_provider.dart';

class ArtworkImage extends ConsumerStatefulWidget {
  final String? url;
  final double size;
  final double radius;
  final bool isCircle;

  const ArtworkImage({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 8,
    this.isCircle = false,
  });

  @override
  ConsumerState<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends ConsumerState<ArtworkImage> {
  bool _useProxyFallback = false;

  @override
  void didUpdateWidget(covariant ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _useProxyFallback = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.isCircle ? widget.size / 2 : widget.radius;
    final rawUrl = widget.url;
    final api = ref.watch(apiClientProvider);

    String? resolvedUrl;
    Map<String, String>? headers;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (_useProxyFallback && !rawUrl.contains('/api/music/artwork')) {
        resolvedUrl = api.buildArtworkProxyUrl(rawUrl);
        headers = api.authHeaders;
      } else {
        resolvedUrl = rawUrl;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: resolvedUrl != null && resolvedUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: resolvedUrl,
                httpHeaders: headers,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) {
                  if (!_useProxyFallback && rawUrl != null && !rawUrl.contains('/api/music/artwork')) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_useProxyFallback) {
                        setState(() => _useProxyFallback = true);
                      }
                    });
                  }
                  return _fallback();
                },
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF282828), Color(0xFF161616)],
        ),
      ),
      child: Center(
        child: Icon(
          widget.isCircle ? Icons.person_rounded : Icons.music_note_rounded,
          color: AppColors.textSecondary,
          size: (widget.size * 0.4).clamp(16.0, 64.0),
        ),
      ),
    );
  }
}
