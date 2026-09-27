import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A `ShadCard` with a plain string title/description, the shape every
/// screen in this demo needs.
class SectionCard extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final Widget? footer;

  const SectionCard({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      title: Text(title),
      description: description == null ? null : Text(description!),
      footer: footer,
      child: child,
    );
  }
}
