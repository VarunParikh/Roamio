import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roamio/core/config/remote_config.dart';
import 'package:roamio/core/data/categories.dart';
import 'package:roamio/core/privacy/privacy_policy.dart';
import 'package:roamio/features/adventures/domain/adventure.dart';
import 'package:roamio/features/auth/ui/auth_scaffold.dart';
import 'package:roamio/features/splits/data/export_service.dart';
import 'package:roamio/features/splits/domain/split_report.dart';
import 'package:roamio/features/tabs/data/tab_service.dart';
import 'package:roamio/features/tabs/ui/tabs_section.dart';
import 'package:share_plus/share_plus.dart';

/// Remote Config `export_enabled` (spec §11), on unless switched off there.
final exportEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).exportEnabled,
);

/// Sends files to Android's share sheet; overridden in `main.dart` and
/// tests. Takes the files and the names they should have.
final shareFilesProvider =
    Provider<Future<void> Function(List<XFile> files, List<String> names)>(
      (ref) =>
          throw UnimplementedError('shareFilesProvider must be overridden'),
    );

/// "Export" (spec UC-27): PDF or Excel of [adventure]'s split, shared
/// through the share sheet. A minor's export leaves location out (§7.2).
Future<void> showExportSheet(
  BuildContext context,
  WidgetRef ref, {
  required Adventure adventure,
  required SplitReport report,
}) async {
  final pdf = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF'),
            subtitle: const Text('To read or print'),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Excel (.xlsx)'),
            subtitle: const Text('To sort and add up'),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  if (pdf == null || !context.mounted) return;

  final data = buildExportData(
    adventure: adventure,
    tabs: ref.read(tabsProvider(adventure.id)).value ?? const [],
    report: report,
    names: squadLabels(ref, adventure),
    categories: {
      for (final c in ref.read(categoriesProvider).value ?? const <Category>[])
        c.id: c.name,
    },
    includeLocation: ref.read(privacyPolicyProvider).allowsLocation,
  );
  final name = '${adventure.name} split.${pdf ? 'pdf' : 'xlsx'}';
  final file = pdf
      ? XFile.fromData(
          await buildPdf(data),
          mimeType: 'application/pdf',
          name: name,
        )
      : XFile.fromData(
          buildXlsx(data),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: name,
        );
  try {
    await ref.read(shareFilesProvider)([file], [name]);
  } on Exception {
    if (context.mounted) showAuthMessage(context, 'Couldn’t share the file.');
  }
}
