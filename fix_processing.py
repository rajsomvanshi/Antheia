import codecs

def fix_processing_screen():
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/processing_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Restore 10/10 text
    content = content.replace("child: const Icon(Icons.auto_awesome_rounded, size: 36, color: Color(0xFF6C5CE7)),", "const Text('10/10', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),")

    # Replace empty emoji
    content = content.replace("const Text('', style: TextStyle(fontSize: 36)),", "const Icon(Icons.auto_awesome_rounded, size: 36, color: Color(0xFF6C5CE7)),")

    with codecs.open('d:/lumina journel/flowjournal/lib/screens/processing_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

fix_processing_screen()
