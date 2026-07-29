import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/connectivity_provider.dart';
import '../providers/comment_tree_provider.dart';
import '../services/websocket_service.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, CommentTreeProvider>(
      builder: (context, connectivity, commentTree, _) {
        final isOnline = connectivity.isOnline;
        final wsStatus = commentTree.wsStatus;

        if (isOnline && wsStatus == WsConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        String message = '';
        Color bgColor = AppConstants.dangerColor;
        IconData icon = Icons.wifi_off_rounded;

        if (!isOnline) {
          message = 'No internet connection. Retrying...';
          bgColor = AppConstants.dangerColor;
          icon = Icons.wifi_off_rounded;
        } else if (wsStatus == WsConnectionStatus.reconnecting || wsStatus == WsConnectionStatus.connecting) {
          message = 'Reconnecting to real-time live sync...';
          bgColor = AppConstants.warningColor;
          icon = Icons.sync_rounded;
        } else if (wsStatus == WsConnectionStatus.disconnected) {
          message = 'Real-time WebSocket disconnected.';
          bgColor = AppConstants.dangerColor;
          icon = Icons.error_outline_rounded;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: bgColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
