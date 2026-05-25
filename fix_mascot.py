import codecs

def fix_mascot():
    with codecs.open('d:/lumina journel/flowjournal/lib/widgets/floating_mascot_fab.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace empty emoji
    content = content.replace("const Text('', style: TextStyle(fontSize: 24)),", "const Icon(Icons.auto_awesome_rounded, size: 24, color: Colors.white),")

    with codecs.open('d:/lumina journel/flowjournal/lib/widgets/floating_mascot_fab.dart', 'w', encoding='utf-8') as f:
        f.write(content)

fix_mascot()
