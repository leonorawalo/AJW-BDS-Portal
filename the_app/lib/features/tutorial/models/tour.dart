/// A short guided tour of one page: a few bubbles, each pointing at a
/// spot on the screen (see TourAnchor) with a title and 2-3 sentences.
class Tour {
  const Tour(this.id, this.steps);

  /// Stored in the user's account once seen, e.g. 'consultant.tasks'.
  /// Never rename one: a new id shows the tour again to everyone.
  final String id;
  final List<TourStep> steps;
}

class TourStep {
  const TourStep({required this.title, required this.body, this.anchors = const []});

  final String title;
  final String body;

  /// Anchor ids to point at; the first one on screen wins (e.g. a menu
  /// item on a laptop, the hamburger on a phone). Empty = a centred bubble
  /// with no spotlight. If none of them is on screen, the step is skipped.
  final List<String> anchors;

  bool get centred => anchors.isEmpty;
}
