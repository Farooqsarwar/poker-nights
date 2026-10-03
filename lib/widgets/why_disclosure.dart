import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../models/tournament.dart';
import 'min_tap_target.dart';

/// §B4 rule 10 / T138: a reason is one visible sentence, and the rest sits
/// behind a "Why?" link.
///
/// Fed by the engine's own `explain[]` (§F1.1), whose text is written with the
/// summary sentence first. Renders nothing when the engine recorded no
/// explanation for [step] (structures generated before `explain` existed).
class WhyDisclosure extends StatefulWidget {
  const WhyDisclosure({super.key, required this.explanation});

  /// Looks the step up on [structure]; null-safe for legacy structures.
  static Widget? forStep(TournamentStructure structure, String step) {
    final e = structure.explanationFor(step);
    return e == null ? null : WhyDisclosure(explanation: e);
  }

  final StructureExplanation explanation;

  @override
  State<WhyDisclosure> createState() => _WhyDisclosureState();
}

class _WhyDisclosureState extends State<WhyDisclosure> {
  bool _open = false;

  /// Splits at the first sentence end. A full stop inside a number ("1.25")
  /// is not one, so it must be followed by whitespace.
  (String, String) _split(String text) {
    final m = RegExp(r'[.!?](\s|$)').firstMatch(text);
    if (m == null) return (text.trim(), '');
    final cut = m.start + 1;
    return (text.substring(0, cut).trim(), text.substring(cut).trim());
  }

  @override
  Widget build(BuildContext context) {
    final (summary, rest) = _split(widget.explanation.text);
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: summary,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
              children: [
                if (rest.isNotEmpty)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: MinTapTarget(
                      child: InkWell(
                        onTap: () => setState(() => _open = !_open),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            _open ? 'Less' : 'Why?',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_open && rest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                rest,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
