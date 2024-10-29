class UnboardingContent {
  String image;
  String title;
  String description;
  UnboardingContent(
      {required this.description, required this.image, required this.title});
}

List<UnboardingContent> contents = [
  UnboardingContent(
      description: 'You can find Cat-sitter',
      image: 'image',
      title: 'Select Cat-sitter'),
  UnboardingContent(
      description: 'You can pay online',
      image: 'image',
      title: 'Easy and Online Payment'),
];
