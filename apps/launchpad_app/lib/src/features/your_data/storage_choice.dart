import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/providers.dart';
import '../../l10n/app_strings.dart';

/// The opt-in to keeping answers on the device.
///
/// It is a choice with two real outcomes, not a banner to dismiss: nothing is
/// saved until "Save on this device" is pressed, and the same control turns it
/// off again and erases the copy.
class StorageChoice extends ConsumerStatefulWidget {
  const StorageChoice({super.key});

  @override
  ConsumerState<StorageChoice> createState() => _StorageChoiceState();
}

class _StorageChoiceState extends ConsumerState<StorageChoice> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final enabled = ref.watch(storageEnabledProvider);
    final available = ref.watch(durableStorageAvailableProvider);
    final problem = ref.watch(storageProblemProvider);
    final controller = ref.read(storageEnabledProvider.notifier);

    if (!available) {
      return NoticeCard(
        title: strings.storageHeading,
        text: strings.storageUnavailable,
        icon: Icons.save_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NoticeCard(
          title: strings.storageHeading,
          text: enabled ? strings.storageOnBody : strings.storageOffBody,
          icon: enabled ? Icons.save : Icons.save_outlined,
          action: enabled
              ? OutlinedButton(
                  onPressed: () async {
                    await controller.disable();
                    if (!mounted) return;
                    setState(() => _status = strings.storageDisabledStatus);
                  },
                  child: Text(strings.storageDisable),
                )
              : FilledButton.tonal(
                  onPressed: () async {
                    await controller.enable();
                    if (!mounted) return;
                    setState(
                      () => _status = ref.read(storageEnabledProvider)
                          ? strings.storageEnabledStatus
                          : null,
                    );
                  },
                  child: Text(strings.storageEnable),
                ),
        ),
        StatusLine(message: problem ? strings.storageProblem : _status),
      ],
    );
  }
}
