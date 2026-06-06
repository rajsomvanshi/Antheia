import 'package:flutter_test/flutter_test.dart';
import 'package:antheia/services/reflection_pipeline.dart';

void main() {
  group('ReflectionPipeline Classification Tests', () {
    test('Classifies vent transcripts correctly', () {
      final mode = ReflectionPipeline.classifyTranscript(
        'I am so frustrated and annoyed with how things went at work today. It is completely unfair.',
      );
      expect(mode, ReflectionMode.vent);
    });

    test('Classifies gratitude transcripts correctly', () {
      final mode = ReflectionPipeline.classifyTranscript(
        'I am so grateful and thankful for this beautiful, wonderful day. I love my family.',
      );
      expect(mode, ReflectionMode.gratitude);
    });

    test('Classifies emotional transcripts correctly', () {
      final mode = ReflectionPipeline.classifyTranscript(
        'I feel so sad and lonely after the breakup. I am crying and struggling through this difficult loss.',
      );
      expect(mode, ReflectionMode.emotional);
    });

    test('Classifies growth transcripts correctly', () {
      final mode = ReflectionPipeline.classifyTranscript(
        'Today I learned a valuable lesson about patience. I realized how much I have grown and improved my mindset.',
      );
      expect(mode, ReflectionMode.growth);
    });

    test('Classifies memory/reflection transcripts correctly', () {
      final mode = ReflectionPipeline.classifyTranscript(
        'I remember when we used to play in the backyard as kids. Looking back, those childhood memories are special.',
      );
      expect(mode, ReflectionMode.reflection);
    });

    test('Classifies life updates correctly', () {
      final mode = ReflectionPipeline.classifyTranscript(
        'Today I went to the park and met with my friends for lunch. Then I finished my homework at school.',
      );
      expect(mode, ReflectionMode.lifeUpdate);
    });
  });
}
