import 'package:flutter/material.dart';

import '../formatters.dart';

enum SyncConflictChoice { local, remote }

class SyncConflictCandidate {
  const SyncConflictCandidate({
    required this.title,
    required this.subtitle,
    required this.platform,
    required this.modifiedAt,
  });

  final String title;
  final String subtitle;
  final String platform;
  final DateTime? modifiedAt;
}

class SyncConflictResolution {
  const SyncConflictResolution({
    required this.choice,
    required this.applyToAll,
  });

  final SyncConflictChoice choice;
  final bool applyToAll;
}

class SyncConflictDialog extends StatefulWidget {
  const SyncConflictDialog({
    required this.local,
    required this.remote,
    super.key,
  });

  final SyncConflictCandidate local;
  final SyncConflictCandidate remote;

  @override
  State<SyncConflictDialog> createState() => _SyncConflictDialogState();
}

class _SyncConflictDialogState extends State<SyncConflictDialog> {
  SyncConflictChoice _choice = SyncConflictChoice.local;
  bool _applyToAll = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolver conflicto'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConflictOption(
              value: SyncConflictChoice.local,
              selected: _choice,
              candidate: widget.local,
              onChanged: (value) => setState(() => _choice = value),
            ),
            const SizedBox(height: 10),
            _ConflictOption(
              value: SyncConflictChoice.remote,
              selected: _choice,
              candidate: widget.remote,
              onChanged: (value) => setState(() => _choice = value),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _applyToAll,
              title: const Text('Aplicar esta decision a todos'),
              onChanged: (value) =>
                  setState(() => _applyToAll = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            SyncConflictResolution(choice: _choice, applyToAll: _applyToAll),
          ),
          child: const Text('Conservar seleccion'),
        ),
      ],
    );
  }
}

class _ConflictOption extends StatelessWidget {
  const _ConflictOption({
    required this.value,
    required this.selected,
    required this.candidate,
    required this.onChanged,
  });

  final SyncConflictChoice value;
  final SyncConflictChoice selected;
  final SyncConflictCandidate candidate;
  final ValueChanged<SyncConflictChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: value == selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            value == selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: value == selected
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: Text(candidate.title),
          subtitle: Text(
            '${candidate.subtitle}\n${candidate.platform} / ${formatDateTime(candidate.modifiedAt)}',
          ),
        ),
      ),
    );
  }
}
