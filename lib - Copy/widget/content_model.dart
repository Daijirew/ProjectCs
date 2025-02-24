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
      image: 'images/meow.png',
      title: 'Select Cat-sitter'),
  UnboardingContent(
      description: 'You can pay online',
      image: 'images/godji.png',
      title: 'Easy and Online Payment'),
  UnboardingContent(
      description: 'You can choose cat-sitter option',
      image: 'images/ped.png',
      title: 'Choose how to sitting your cat'),
];
