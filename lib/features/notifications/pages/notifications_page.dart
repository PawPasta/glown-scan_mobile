import 'package:flutter/material.dart';

import '../services/notification_api.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({this.api, super.key});
  final NotificationApiContract? api;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationApiContract _api = widget.api ?? NotificationApi();
  late Future<_NotificationData> _data = _load();
  Future<_NotificationData> _load() async => _NotificationData(
    await _api.getPreferences(),
    await _api.getNotifications(),
  );
  @override
  void dispose() {
    if (widget.api == null && _api is NotificationApi) {
      (_api).close();
    }
    super.dispose();
  }

  Future<void> _save(NotificationPreferences value) async {
    await _api.savePreferences(value);
    if (mounted) setState(() => _data = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<_NotificationData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: () => setState(() => _data = _load()),
              child: const Text('Try again'),
            ),
          );
        }
        final data = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(
              title: const Text('Routine reminders'),
              value: data.preferences.routineReminders,
              onChanged: (v) => _save(
                NotificationPreferences(
                  routineReminders: v,
                  analysisUpdates: data.preferences.analysisUpdates,
                  productRecommendations:
                      data.preferences.productRecommendations,
                  marketing: data.preferences.marketing,
                  reminderTime: data.preferences.reminderTime,
                  timezone: data.preferences.timezone,
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Analysis updates'),
              value: data.preferences.analysisUpdates,
              onChanged: (v) => _save(
                NotificationPreferences(
                  routineReminders: data.preferences.routineReminders,
                  analysisUpdates: v,
                  productRecommendations:
                      data.preferences.productRecommendations,
                  marketing: data.preferences.marketing,
                  reminderTime: data.preferences.reminderTime,
                  timezone: data.preferences.timezone,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Inbox', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                await _api.markAllRead();
                if (mounted) setState(() => _data = _load());
              },
              child: const Text('Mark all as read'),
            ),
            ...data.items.map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text(item.body),
                trailing: item.read ? null : const Icon(Icons.circle, size: 10),
                onTap: () async {
                  if (!item.read) {
                    await _api.markRead(item.id);
                    if (mounted) setState(() => _data = _load());
                  }
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _NotificationData {
  const _NotificationData(this.preferences, this.items);
  final NotificationPreferences preferences;
  final List<AppNotification> items;
}
