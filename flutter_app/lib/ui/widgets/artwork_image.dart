import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/settings_provider.dart';

class ArtworkImage extends ConsumerStatefulWidget {
  final String? url;
  final double size;
  final double? width;
  final double? height;
  final double radius;
  final bool isCircle;
  final BoxFit fit;
  final bool preserveFull;

  const ArtworkImage({
    super.key,
    required this.url,
    this.size = 56,
    this.width,
    this.height,
    this.radius = 8,
    this.isCircle = false,
    this.fit = BoxFit.cover,
    this.preserveFull = false,
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
    final w = widget.width ?? widget.size;
    final h = widget.height ?? widget.size;
    final effectiveRadius = widget.isCircle ? (w < h ? w : h) / 2 : widget.radius;
    final rawUrl = widget.url;
    final api = ref.watch(apiClientProvider);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = ((w > h ? w : h) * dpr).round().clamp(96, 1024);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    Widget buildNetworkImage(BoxFit activeFit) {
      return CachedNetworkImage(
        imageUrl: resolvedUrl!,
        httpHeaders: headers,
        fit: activeFit,
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
      );
    }

    Widget content;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      content = _fallback();
    } else if (widget.preserveFull) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: isDark ? const Color(0xFF14171E) : const Color(0xFFE9ECF2),
          ),
          Opacity(
            opacity: isDark ? 0.34 : 0.24,
            child: buildNetworkImage(BoxFit.cover),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0x52000000), Color(0x66000000)]
                    : const [Color(0x38FFFFFF), Color(0x48FFFFFF)],
              ),
            ),
          ),
          buildNetworkImage(BoxFit.contain),
        ],
      );
    } else {
      content = buildNetworkImage(widget.fit);
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: SizedBox(
          width: w,
          height: h,
          child: content,
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
