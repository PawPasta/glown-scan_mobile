import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
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
  bool _isLoadingMore = false;
  Future<_NotificationData> _load() async => _NotificationData(
    await _api.getPreferences(),
    await _api.getNotifications(),
  );

  Future<void> _loadMore(_NotificationData current) async {
    if (_isLoadingMore || !current.inbox.hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final next = await _api.getNotifications(
        page: current.inbox.page + 1,
        limit: current.inbox.limit,
      );
      if (mounted) {
        setState(() {
          _data = Future.value(
            _NotificationData(
              current.preferences,
              NotificationInbox(
                items: [...current.inbox.items, ...next.items],
                total: next.total,
                page: next.page,
                limit: next.limit,
              ),
            ),
          );
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    if (widget.api == null && _api is NotificationApi) {
      (_api).close();
    }
    super.dispose();
  }

  Future<void> _save(NotificationPreferences value) async {
    await _api.savePreferences(value);
    if (mounted) {
      setState(() {
        _data = _load();
      });
    }
  }

  NotificationPreferences _copyPreferences(
    NotificationPreferences current, {
    bool? routineReminders,
    bool? analysisUpdates,
    bool? productRecommendations,
    bool? marketing,
  }) => NotificationPreferences(
    routineReminders: routineReminders ?? current.routineReminders,
    analysisUpdates: analysisUpdates ?? current.analysisUpdates,
    productRecommendations:
        productRecommendations ?? current.productRecommendations,
    marketing: marketing ?? current.marketing,
    reminderTime: current.reminderTime,
    timezone: current.timezone,
  );

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
              onPressed: () => setState(() {
                _data = _load();
              }),
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
                _copyPreferences(data.preferences, routineReminders: v),
              ),
            ),
            SwitchListTile(
              title: const Text('Analysis updates'),
              value: data.preferences.analysisUpdates,
              onChanged: (v) =>
                  _save(_copyPreferences(data.preferences, analysisUpdates: v)),
            ),
            SwitchListTile(
              title: const Text('Product recommendations'),
              value: data.preferences.productRecommendations,
              onChanged: (v) => _save(
                _copyPreferences(data.preferences, productRecommendations: v),
              ),
            ),
            SwitchListTile(
              title: const Text('Marketing updates'),
              value: data.preferences.marketing,
              onChanged: (v) =>
                  _save(_copyPreferences(data.preferences, marketing: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Routine reminder time'),
              subtitle: Text(
                data.preferences.reminderTime ?? 'Not configured by server',
              ),
              trailing: Text(data.preferences.timezone ?? ''),
            ),
            const SizedBox(height: 18),
            Text('Inbox', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                await _api.markAllRead();
                if (mounted) {
                  setState(() {
                    _data = _load();
                  });
                }
              },
              child: const Text('Mark all as read'),
            ),
            ...data.inbox.items.map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text(
                  item.createdAt == null
                      ? item.body
                      : '${item.body}\n${item.createdAt}',
                ),
                trailing: item.read ? null : const Icon(Icons.circle, size: 10),
                onTap: () async {
                  if (!item.read) {
                    await _api.markRead(item.id);
                    if (mounted) {
                      setState(() {
                        _data = _load();
                      });
                    }
                  }
                },
              ),
            ),
            if (data.inbox.hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: _isLoadingMore ? null : () => _loadMore(data),
                  icon: _isLoadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(_isLoadingMore ? 'Loading…' : 'Load more'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _NotificationData {
  const _NotificationData(this.preferences, this.inbox);
  final NotificationPreferences preferences;
  final NotificationInbox inbox;

  List<AppNotification> get items => inbox.items;
}
