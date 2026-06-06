import 'package:flutter_test/flutter_test.dart';
import 'package:antheia/services/voice_filter_service.dart';

void main() {
  group('VoiceFilterService Tests', () {
    test('strips filler words case-insensitively', () {
      expect(
        VoiceFilterService.clean('Um, I went to the store like basically today'),
        'I went to the store today.',
      );
      expect(
        VoiceFilterService.clean('uhh that was sort of cool'),
        'That was cool.',
      );
    });

    test('deduplicates immediately repeated words', () {
      expect(
        VoiceFilterService.clean('I I went to to the the library'),
        'I went to the library.',
      );
    });

    test('softens profanities', () {
      expect(
        VoiceFilterService.clean('this is fucking amazing'),
        'This is — amazing.',
      );
      expect(
        VoiceFilterService.clean('shit happened'),
        '— happened.',
      );
    });

    test('capitalizes first letter of each sentence and infers punctuation', () {
      expect(
        VoiceFilterService.clean('hello world this is great! how are you'),
        'Hello world this is great! How are you.',
      );
    });

    test('normalizes excessive whitespace', () {
      expect(
        VoiceFilterService.clean('   hello    world  '),
        'Hello world.',
      );
    });
  });
}
