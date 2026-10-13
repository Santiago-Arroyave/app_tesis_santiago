import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goblink_park/providers/notification_provider.dart';
import 'package:goblink_park/screens/profile/notifications_screen.dart';

class NotificationBellButton extends StatelessWidget {
  final Color? color;
  final double size;

  const NotificationBellButton({
    super.key,
    this.color,
    this.size = 25,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE8F5E9)
            : const Color(0xFF0F3A22));

    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, child) {
        final unread = notifProvider.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: effectiveColor, size: size),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  child: Center(
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
