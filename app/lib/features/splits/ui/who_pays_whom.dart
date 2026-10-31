import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';
import 'package:roamio/features/splits/domain/settlement_planner.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';

/// Who pays whom (spec UC-25): the first [_collapsedRows] rows, then View all.
/// Rows the viewer can act on come first, so they're never behind View all,
/// and only those have an arrow.
class WhoPaysWhom extends StatefulWidget {
  const new({
    required this.transfers,
    required this.people,
    required this.myUid,
    required this.nameOf,
    required this.amountOf,
    required this.mayAct,
    required this.onAct,
    super.key,
  });

  final List<Transfer> transfers;
  final Map<String, SquadPerson> people;
  final String myUid;

  /// Someone's name, for someone who isn't the viewer.
  final String Function(String id) nameOf;
  final String Function(Transfer transfer) amountOf;
  final bool Function(Transfer transfer) mayAct;
  final ValueChanged<Transfer> onAct;

  @override
  State<WhoPaysWhom> createState() => _WhoPaysWhomState();
}

const _collapsedRows = 4;

class _WhoPaysWhomState extends State<WhoPaysWhom> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ordered = [
      ...widget.transfers.where(widget.mayAct),
      ...widget.transfers.where((t) => !widget.mayAct(t)),
    ];
    final shown = _all ? ordered : ordered.take(_collapsedRows).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Who pays whom', style: text.headlineSmall)),
            if (ordered.length > _collapsedRows)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? 'Show fewer' : 'View all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ordered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Everyone is square 🎉', style: text.bodyLarge),
                )
              : Column(
                  children: [
                    for (final (i, t) in shown.indexed) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: RoamioColors.hairline,
                        ),
                      TransferRow(
                        key: ValueKey('transfer-${t.from}-${t.to}'),
                        from: t.from,
                        to: t.to,
                        amount: widget.amountOf(t),
                        people: widget.people,
                        myUid: widget.myUid,
                        nameOf: widget.nameOf,
                        onTap: widget.mayAct(t) ? () => widget.onAct(t) : null,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// One payment: picture and name, "pays ₹500", picture and name. TalkBack
/// reads it as one sentence.
class TransferRow extends StatelessWidget {
  const new({
    required this.from,
    required this.to,
    required this.amount,
    required this.people,
    required this.myUid,
    required this.nameOf,
    required this.onTap,
    super.key,
  });

  final String from;
  final String to;
  final String amount;
  final Map<String, SquadPerson> people;
  final String myUid;
  final String Function(String id) nameOf;

  /// Null when the viewer may not record this payment.
  final VoidCallback? onTap;

  String get _sentence => from == myUid
      ? 'You pay ${nameOf(to)} $amount'
      : to == myUid
      ? '${nameOf(from)} pays you $amount'
      : '${nameOf(from)} pays ${nameOf(to)} $amount';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null ? _sentence : '$_sentence. Mark as settled',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(RoamioRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              _End(id: from, row: this),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'pays ',
                              style: text.bodySmall?.copyWith(
                                color: RoamioColors.slate,
                              ),
                            ),
                            TextSpan(
                              text: amount,
                              style: text.titleSmall?.copyWith(
                                color: RoamioColors.mintText,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Row(
                        children: [
                          Expanded(
                            child: Divider(color: RoamioColors.hairline),
                          ),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: RoamioColors.slate,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _End(id: to, row: this),
              SizedBox(
                width: 24,
                child: onTap == null
                    ? null
                    : const Icon(
                        Icons.chevron_right,
                        color: RoamioColors.slate,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One end of a payment: a picture with the name under it.
class _End extends StatelessWidget {
  const new({required this.id, required this.row});

  final String id;
  final TransferRow row;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    child: Column(
      children: [
        PersonAvatar(uid: id, person: row.people[id]),
        const SizedBox(height: 4),
        Text(
          id == row.myUid ? 'You' : row.nameOf(id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
