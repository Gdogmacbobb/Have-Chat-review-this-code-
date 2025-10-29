class PerformanceCategories {
  static const Map<String, List<String>> categories = {
    'Music': [
      'Acoustic / Singer-Songwriter',
      'Band',
      'Instrumental',
      'DJ / Electronic',
      'A Cappella / Vocal',
      'Looping / One-Man Band',
      'Street Opera',
      'Jazz',
      'Blues / Folk',
    ],
    'Dance': [
      'Hip-Hop / Breaking',
      'Locking / Popping',
      'House',
      'Waacking / Voguing',
      'Contemporary / Interpretive',
      'Ballet / Classical',
      'Cultural / Folk Dance',
      'Tap Dancing',
    ],
    'Visual Arts': [
      'Live Painting / Mural',
      'Portrait / Caricature',
      'Chalk Art',
      'Sand Art',
      'Balloon Art',
      'Graffiti / Spray Art',
      'Body Art / Face Painting',
    ],
    'Comedy': [
      'Stand-Up',
      'Improv',
      'Street Comedy',
      'Mime / Physical Comedy',
      'Clown / Character',
    ],
    'Magic': [
      'Close-Up / Street Magic',
      'Card Tricks',
      'Illusions',
      'Mentalism',
      'Sleight of Hand',
    ],
    'Other': [
      'Acrobatics',
      'Juggling',
      'Fire Performance',
      'Puppetry',
      'Living Statue',
      'Circus Arts',
      'Spoken Word / Poetry',
      'Beatboxing',
    ],
  };

  static const Map<String, String> categoryIcons = {
    'Music': 'music_note',
    'Dance': 'person_dancing',
    'Visual Arts': 'palette',
    'Comedy': 'theater_comedy',
    'Magic': 'auto_awesome',
    'Other': 'category',
  };

  static const Map<String, String> categoryEmojis = {
    'Music': '🎵',
    'Dance': '💃',
    'Visual Arts': '🎨',
    'Comedy': '🎭',
    'Magic': '✨',
    'Other': '⭐',
  };

  static List<String> getMainCategories() {
    return categories.keys.toList();
  }

  static List<String> getSubcategories(String mainCategory) {
    return categories[mainCategory] ?? [];
  }

  static String getIcon(String mainCategory) {
    return categoryIcons[mainCategory] ?? 'category';
  }

  static String getEmoji(String mainCategory) {
    return categoryEmojis[mainCategory] ?? '⭐';
  }
}
