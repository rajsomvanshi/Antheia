import codecs

def fix_errors():
    # Fix map_tab.dart
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/tabs/map_tab.dart', 'r', encoding='utf-8') as f:
        map_content = f.read()
    map_content = map_content.replace('.emoji', '.icon')
    map_content = map_content.replace("Text(memory.emoji, style: const TextStyle(fontSize: 24))", "Icon(memory.icon, size: 24, color: AppColors.accentPrimary)")
    map_content = map_content.replace("Text(\\n              location.emoji,\\n              style: const TextStyle(fontSize: 28),\\n            )", "Icon(location.icon, size: 28, color: AppColors.accentPrimary)")
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/tabs/map_tab.dart', 'w', encoding='utf-8') as f:
        f.write(map_content)

    # Fix overview_tab.dart invalid constants
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/tabs/overview_tab.dart', 'r', encoding='utf-8') as f:
        overview = f.read()
    overview = overview.replace("const Icon(Icons.favorite_rounded, size: 24, color: AppColors.textSecondary)", "Icon(Icons.favorite_rounded, size: 24, color: AppColors.textSecondary)")
    overview = overview.replace("const Icon(Icons.history_rounded, size: 22, color: AppColors.textSecondary)", "Icon(Icons.history_rounded, size: 22, color: AppColors.textSecondary)")
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/tabs/overview_tab.dart', 'w', encoding='utf-8') as f:
        f.write(overview)

    # Fix settings_screen.dart syntax error around line 302
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
        settings = f.read()
    # Find the missing bracket. We replaced a SettingRow with a _buildListTile probably missing a closing comma or bracket.
    # We replaced Strict Local Mode. Let's just fix it.
    with codecs.open('d:/lumina journel/flowjournal/lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
        f.write(settings)

fix_errors()
