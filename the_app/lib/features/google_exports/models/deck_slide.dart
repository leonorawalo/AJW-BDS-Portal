/// One "title and body" slide of an exported Google Slides deck.
class DeckSlide {
  const DeckSlide({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  Map<String, dynamic> toJson() => {'title': title, 'bullets': bullets};
}
