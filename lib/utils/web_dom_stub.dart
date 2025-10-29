// Stub for non-web platforms
class Document {
  ElementList getElementsByTagName(String tag) => ElementList();
}

class ElementList {
  int get length => 0;
}

final document = Document();
