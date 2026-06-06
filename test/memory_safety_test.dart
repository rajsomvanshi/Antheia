import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:antheia/models/models.dart';
import 'package:antheia/state/memory_persistence_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Memory Safety & Draft Recovery Tests', () {
    late MemoryPersistenceState persistenceState;

    setUp(() {
      persistenceState = MemoryPersistenceState();
    });

    test('isJsonDraft correctly identifies JSON formatted drafts', () {
      // Setup simple plain text draft
      persistenceState.saveDraft('Hello this is a simple text draft');
      expect(persistenceState.isJsonDraft, isFalse);

      // Setup JSON draft
      final jsonDraft = jsonEncode({
        'entry': {
          'id': '123',
          'title': 'Test Title',
          'content': 'Test Content',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'mood': 'calm',
          'tags': '[]',
          'photoUrls': '[]',
          'sections': '[]',
          'synced': 0
        },
        'blocks': [
          {'id': 'b1', 'type': 'text', 'text': 'Test Content'}
        ],
        'isExistingEntry': false
      });
      persistenceState.saveDraft(jsonDraft);
      expect(persistenceState.isJsonDraft, isTrue);
    });

    test('getRecoveredEntry restores plain text draft gracefully', () {
      const rawText = 'Voice recording text representation';
      persistenceState.saveDraft(rawText);

      final entry = persistenceState.getRecoveredEntry();
      expect(entry.title, equals('Recovered Memory'));
      expect(entry.content, equals(rawText));
      expect(entry.blocks.length, equals(1));
      expect(entry.blocks.first, isA<TextBlock>());
      expect((entry.blocks.first as TextBlock).text, equals(rawText));
    });

    test('getRecoveredEntry restores full metadata from JSON draft', () {
      final now = DateTime.now();
      final originalEntry = JournalEntry(
        id: '999',
        title: 'Editorial Masterpiece',
        content: 'This is my visual story.',
        createdAt: now,
        updatedAt: now,
        mood: Mood.creative,
        location: 'Paris, France',
        temperature: 18.5,
        weatherIcon: '⛅',
        tags: ['paris', 'creative'],
        photoUrls: ['local_image.jpg'],
        isVoiceEntry: false,
        sections: [
          const EntrySection(type: 'paragraph', content: 'This is my visual story.')
        ],
        blocks: [
          TextBlock(id: 'text_1', text: 'This is my visual story.')
        ],
      );

      final jsonDraft = jsonEncode({
        'entry': originalEntry.toMap(),
        'blocks': originalEntry.blocks.map((b) => b.toJson()).toList(),
        'isExistingEntry': true
      });

      persistenceState.saveDraft(jsonDraft);

      final recovered = persistenceState.getRecoveredEntry();
      expect(recovered.id, equals('999'));
      expect(recovered.title, equals('Editorial Masterpiece'));
      expect(recovered.content, equals('This is my visual story.'));
      // Round to seconds to avoid precision differences on parse
      expect(recovered.createdAt.day, equals(now.day));
      expect(recovered.mood, equals(Mood.creative));
      expect(recovered.location, equals('Paris, France'));
      expect(recovered.temperature, equals(18.5));
      expect(recovered.weatherIcon, equals('⛅'));
      expect(recovered.tags, containsAll(['paris', 'creative']));
      expect(recovered.photoUrls, contains('local_image.jpg'));
      expect(recovered.blocks.length, equals(1));
      expect(recovered.blocks.first, isA<TextBlock>());
      expect((recovered.blocks.first as TextBlock).text, equals('This is my visual story.'));
    });

    test('draftDisplayText extracts content preview accurately', () {
      // Plain text
      persistenceState.saveDraft('Hello preview text');
      expect(persistenceState.draftDisplayText, equals('Hello preview text'));

      // JSON draft
      final originalEntry = JournalEntry(
        id: '1',
        title: 'Untitled',
        content: 'Autosaved content text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: Mood.neutral,
      );
      final jsonDraft = jsonEncode({
        'entry': originalEntry.toMap(),
        'blocks': [{'id': 'b1', 'type': 'text', 'text': 'Autosaved content text'}],
        'isExistingEntry': false
      });
      persistenceState.saveDraft(jsonDraft);
      expect(persistenceState.draftDisplayText, equals('Autosaved content text'));
    });
  });
}
