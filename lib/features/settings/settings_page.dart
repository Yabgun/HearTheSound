import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/notification_service.dart';
import '../../state/progress_controller.dart';
import '../../state/settings_controller.dart';
import '../calibration/calibration_page.dart';
import '../explorer/range_playground_page.dart';

// -----------------------------------------------------------------------------
// AYARLAR — ses aralığı kalibrasyonu + günlük hatırlatma bildirimi
// -----------------------------------------------------------------------------

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _fmt(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final range = ref.watch(progressProvider).vocalRange;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.graphic_eq_rounded),
            title: const Text('Ses aralığı'),
            subtitle: Text(
              range == null
                  ? 'Henüz kalibre edilmedi — dokun ve ölç'
                  : 'Rahat: ${range.comfortLowNote.label} – ${range.comfortHighNote.label}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CalibrationPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.explore_rounded),
            title: const Text('Ses aralığı oyun alanı'),
            subtitle: const Text('Keşfet ve sesini genişlet (puansız)'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const RangePlaygroundPage()),
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('Günlük hatırlatma'),
            subtitle: Text(
              settings.reminderEnabled
                  ? 'Her gün ${_fmt(settings.reminderHour)} civarı'
                  : 'Kapalı',
            ),
            value: settings.reminderEnabled,
            onChanged: (value) async {
              if (value) {
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bildirim izni verilmedi.')),
                    );
                  }
                  return;
                }
                await NotificationService.instance
                    .scheduleDaily(hour: settings.reminderHour);
                await ctrl.setEnabled(true);
              } else {
                await NotificationService.instance.cancelDaily();
                await ctrl.setEnabled(false);
              }
            },
          ),
          ListTile(
            enabled: settings.reminderEnabled,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Hatırlatma saati'),
            subtitle: Text(_fmt(settings.reminderHour)),
            onTap: settings.reminderEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay(hour: settings.reminderHour, minute: 0),
                    );
                    if (picked != null) {
                      await ctrl.setHour(picked.hour);
                      await NotificationService.instance
                          .scheduleDaily(hour: picked.hour);
                    }
                  }
                : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.send_rounded),
            title: const Text('Test bildirimi gönder'),
            subtitle: const Text('Hemen bir bildirim at (doğrulama için)'),
            onTap: () async {
              final granted =
                  await NotificationService.instance.requestPermission();
              if (granted) {
                await NotificationService.instance.showTestNow();
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bildirim izni verilmedi.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
