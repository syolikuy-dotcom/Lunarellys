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
  static final Set<String> _failedDirectUrls = <String>{};
  bool _useProxyFallback = false;

  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (url != null && _failedDirectUrls.contains(url)) {
      _useProxyFallback = true;
    }
  }

  @override
  void didUpdateWidget(covariant ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final url = widget.url;
      _useProxyFallback = url != null && _failedDirectUrls.contains(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.isCircle ? widget.size / 2 : widget.radius;
    final rawUrl = widget.url;
    final api = ref.watch(apiClientProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (widget.size * dpr).round().clamp(96, 1024);

    final knownFailed = rawUrl != null && _failedDirectUrls.contains(rawUrl);
    final useProxy = _useProxyFallback || knownFailed;

    String? resolvedUrl;
    Map<String, String>? headers;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (useProxy && !rawUrl.contains('/api/music/artwork')) {
        resolvedUrl = api.buildArtworkProxyUrl(rawUrl);
        headers = api.authHeaders;
      } else {
        resolvedUrl = rawUrl;
      }
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: resolvedUrl != null && resolvedUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: resolvedUrl,
                  httpHeaders: headers,
                  fit: BoxFit.cover,
                  memCacheWidth: cachePx,
                  memCacheHeight: cachePx,
                  filterQuality: FilterQuality.medium,
                  fadeInDuration: const Duration(milliseconds: 120),
                  placeholder: (_, __) => _fallback(),
                  errorWidget: (_, __, ___) {
                    if (!useProxy &&
                        rawUrl != null &&
                        !rawUrl.contains('/api/music/artwork')) {
                      if (_failedDirectUrls.length > 400) {
                        _failedDirectUrls.clear();
                      }
                      _failedDirectUrls.add(rawUrl);
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
      ),
    );
  }

  Widget _fallback() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF232730), Color(0xFF14171D)]
              : const [Color(0xFFE7EAF0), Color(0xFFD9DEE6)],
        ),
      ),
      child: Center(
        child: Icon(
          widget.isCircle ? Icons.person_rounded : Icons.music_note_rounded,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          size: (widget.size * 0.4).clamp(16.0, 64.0),
        ),
      ),
    );
  }
}
