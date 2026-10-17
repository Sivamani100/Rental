import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rental/core/services/network_status_service.dart';

/// Full-width top notification bar matching modern apps (e.g. LinkedIn).
/// Shows "Network offline." in soft red when disconnected,
/// and "Back online." in soft green for 2.6 seconds when reconnected.
class NetworkTopBar extends StatelessWidget {
  const NetworkTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NetworkStatusService.instance,
      builder: (context, _) {
        final isOffline = !NetworkStatusService.instance.isOnline;
        final justReconnected = NetworkStatusService.instance.justReconnected;
        final showBanner = isOffline || justReconnected;

        // Light pastel red for offline, light pastel green for back online
        final bgColor = isOffline
            ? const Color(0xFFFFDFDF)
            : const Color(0xFFDEF7EC);

        final iconColor = isOffline
            ? const Color(0xFFC62828)
            : const Color(0xFF2E7D32);

        final textColor = isOffline
            ? const Color(0xFF1E1E1E)
            : const Color(0xFF0E5A33);

        final statusBarHeight = MediaQuery.of(context).padding.top;
        final totalHeight = showBanner ? (statusBarHeight + 36.0) : 0.0;

        Widget bannerContent = showBanner
            ? Padding(
                padding: EdgeInsets.only(top: statusBarHeight),
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOffline
                              ? Icons.remove_circle
                              : Icons.check_circle_rounded,
                          size: 16,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOffline
                              ? 'No active internet connection'
                              : 'Network restored successfully',
                          style: TextStyle(
                            fontFamily: 'ProximaNova',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();

        if (showBanner) {
          bannerContent = AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            child: bannerContent,
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          height: totalHeight,
          color: bgColor,
          clipBehavior: Clip.hardEdge,
          child: bannerContent,
        );
      },
    );
  }
}

/// Global wrapper that places the [NetworkTopBar] at the very top of the app.
class GlobalNetworkStatusBarWrapper extends StatelessWidget {
  final Widget child;

  const GlobalNetworkStatusBarWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          const NetworkTopBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
