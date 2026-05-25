import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../services/database_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'paywall_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Editor Screen — Rich Journal Entry Editor
// ═══════════════════════════════════════════════════════════════

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  // ─── Toolbar state ───
  int _activeToolbarIndex = -1;

  // ─── AI Suggestion ───
  bool _showAiSuggestion = true;

  // ─── AI Suggestion animation ───
  late final AnimationController _aiSlideController;
  late final Animation<Offset> _aiSlideAnimation;

  // ─── Typography sheet state ───
  int _selectedFontIndex = 0;
  int _selectedStyleIndex = 0;
  double _fontSize = 16;
  double _lineHeight = 1.7;

  // ─── Theme selector state ───
  int _selectedThemeIndex = 0;

  // ─── Photo Frame state ───
  String _selectedPhotoFrame = 'None';
  static const List<String> _photoFrames = ['None', 'Polaroid', 'Circle', 'Heart'];

  // ─── Text Editing Controllers for new entries ───
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _isNewEntry = false;

  // ─── Toolbar button definitions ───
  static const List<String> _toolbarLabels = [
    'B', 'I', 'U', 'H1', 'H2', '•', '"', '📷', 'Aa', '🎨', '✨',
  ];

  // ─── Font options ───
  static const List<String> _fontNames = [
    'Inter',
    'Merriweather',
    'Caveat',
    'JetBrains Mono',
    'Playfair Display',
  ];

  // ─── Style presets ───
  static const List<Map<String, String>> _stylePresets = [
    {'name': 'Journal', 'desc': 'Warm serif feel'},
    {'name': 'Professional', 'desc': 'Clean & sharp'},
    {'name': 'Creative', 'desc': 'Playful vibes'},
    {'name': 'Minimal', 'desc': 'Less is more'},
    {'name': 'Romantic', 'desc': 'Soft & dreamy'},
    {'name': 'Editorial', 'desc': 'Magazine style'},
  ];

  // ─── Theme presets for the selector ───
  static const List<_ThemeCard> _themeCards = [
    _ThemeCard('Pure White', 'Minimal', Color(0xFFFFFFFF), Color(0xFF2D3436), false),
    _ThemeCard('Cream Paper', 'Minimal', Color(0xFFFAF9F6), Color(0xFF2D3436), false),
    _ThemeCard('Slate Dark', 'Minimal', Color(0xFF1A1A2E), Color(0xFFE8E8E8), false),
    _ThemeCard('Forest Mist', 'Nature', Color(0xFFE8F5E9), Color(0xFF1B5E20), false),
    _ThemeCard('Ocean Breeze', 'Nature', Color(0xFFE3F2FD), Color(0xFF0D47A1), false),
    _ThemeCard('Calm Blue', 'Mood', Color(0xFFE8EAF6), Color(0xFF283593), true),
    _ThemeCard('Energetic Orange', 'Mood', Color(0xFFFFF3E0), Color(0xFFE65100), true),
  ];

  // ─── TTS State ───
  late FlutterTts _flutterTts;
  bool _isPlayingVoice = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _aiSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _aiSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _aiSlideController,
      curve: Curves.easeOut,
    ));
    // Start the slide-in after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showAiSuggestion && mounted) {
        _aiSlideController.forward();
      }
    });

    // Detect if we are making a new entry or editing an existing one
    final appState = context.read<AppState>();
    final entry = appState.currentEntry;
    if (entry == null) {
      _isNewEntry = true;
      _titleController = TextEditingController(text: '');
      _bodyController = TextEditingController(text: '');
    } else {
      _isNewEntry = false;
      _titleController = TextEditingController(text: entry.title);
      _bodyController = TextEditingController(text: entry.content);
    }
  }

  @override
  void dispose() {
    _aiSlideController.dispose();
    _flutterTts.stop();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingVoice = false);
    });
  }

  Future<void> _toggleTts() async {
    if (_isPlayingVoice) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isPlayingVoice = false);
      return;
    }

    final appState = context.read<AppState>();
    
    // Map custom string to flutter_tts languages/voices if possible
    // Here we'll just set language based on the selection
    if (appState.ttsVoice.contains('Hindi')) {
      await _flutterTts.setLanguage('hi-IN');
    } else {
      await _flutterTts.setLanguage('en-US');
    }
    
    await _flutterTts.setPitch(appState.ttsPitch);
    await _flutterTts.setSpeechRate(appState.ttsSpeed);

    // Combine all text
    final buffer = StringBuffer();
    buffer.writeln(_entry.title);
    for (final sec in _sections) {
      if (sec.type == 'text' || sec.type == 'h1' || sec.type == 'h2' || sec.type == 'quote' || sec.type == 'bullet') {
        buffer.writeln(sec.content);
      }
    }

    if (mounted) setState(() => _isPlayingVoice = true);
    await _flutterTts.speak(buffer.toString());
  }

  void _dismissAiSuggestion() {
    _aiSlideController.reverse().then((_) {
      if (mounted) {
        setState(() => _showAiSuggestion = false);
      }
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (xFile == null) return;
    
    // Show a snackbar or loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image to cloud...')),
      );
    }
    
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
    String? url;
    try {
      url = await DatabaseService().uploadImage(xFile.path, fileName);
    } catch (e) {
      // Ignored - fallback to local path below
    }
    
    // Fallback to local path if cloud upload fails
    url ??= xFile.path;
    
    if (url != null && mounted) {
      // Create a new photo section
      final newSection = EntrySection(type: 'photo', content: url);
      
      // We should ideally update the app state here. For now, we'll just show success.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded and added!')),
      );
      
      // In a real app, we would add the section to _sections list and save.
      // But since _sections is currently derived from _entry, we update the entry.
      final current = _entry;
      final updatedSections = List<EntrySection>.from(current.sections)..add(newSection);
      final updatedPhotoUrls = List<String>.from(current.photoUrls)..add(url);
      
      final updatedEntry = JournalEntry(
        id: current.id,
        title: current.title,
        content: current.content,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        mood: current.mood,
        location: current.location,
        temperature: current.temperature,
        weatherIcon: current.weatherIcon,
        tags: current.tags,
        photoUrls: updatedPhotoUrls,
        durationMinutes: current.durationMinutes,
        isVoiceEntry: current.isVoiceEntry,
        sections: updatedSections,
      );
      
      // Replace it in AppState
      context.read<AppState>().deleteEntry(current.id);
      context.read<AppState>().addEntry(updatedEntry);
      context.read<AppState>().setCurrentEntry(updatedEntry);
    }
  }

  // ─── Sample entry data ───
  JournalEntry get _entry {
    final appState = context.read<AppState>();
    if (appState.currentEntry != null) {
      return appState.currentEntry!;
    }
    // Return a new empty entry if none is selected
    return JournalEntry(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Entry',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mood: Mood.neutral,
      tags: [],
      sections: [],
    );
  }

  List<EntrySection> get _sections {
    final entry = _entry;
    if (entry.sections.isNotEmpty) return entry.sections;
    // Fallback sample sections
    return const [
      EntrySection(type: 'heading', content: 'Morning Chaos', headingLevel: 2),
      EntrySection(
        type: 'paragraph',
        content:
            'Today was weird… first I missed class because I woke up late. The alarm didn\'t go off, or maybe I just slept through it. Either way, by the time I looked at my phone it was already 9:15.',
      ),
      EntrySection(type: 'bullet', content: 'Missed the 8 AM lecture on distributed systems'),
      EntrySection(type: 'bullet', content: 'Had to take the crowded city bus'),
      EntrySection(type: 'bullet', content: 'Spilled coffee on my notes — classic'),
      EntrySection(type: 'heading', content: 'Unexpected Reunion', headingLevel: 2),
      EntrySection(
        type: 'paragraph',
        content:
            'Then I met Rahul near the library steps. I haven\'t seen him properly since his birthday last month. We sat on the steps for almost an hour just catching up.',
      ),
      EntrySection(
        type: 'quote',
        content:
            'Some people don\'t just return — they reopen old memories you forgot were still alive inside you.',
      ),
    ];
  }

  void _saveEntry(BuildContext context) {
    final appState = context.read<AppState>();
    JournalEntry entryToSave;

    if (_isNewEntry) {
      // Create new entry
      entryToSave = JournalEntry(
        id: 'new_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim().isEmpty ? 'Untitled Entry' : _titleController.text.trim(),
        content: _bodyController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: Mood.neutral,
        tags: [],
        sections: [
          EntrySection(type: 'paragraph', content: _bodyController.text.trim()),
        ],
      );
      appState.addEntry(entryToSave);
    } else {
      // Update existing
      final current = _entry;
      entryToSave = JournalEntry(
        id: current.id,
        title: _titleController.text.trim().isEmpty ? current.title : _titleController.text.trim(),
        content: _bodyController.text.trim().isEmpty ? current.content : _bodyController.text.trim(),
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
        mood: current.mood,
        location: current.location,
        temperature: current.temperature,
        weatherIcon: current.weatherIcon,
        tags: current.tags,
        photoUrls: current.photoUrls,
        durationMinutes: current.durationMinutes,
        isVoiceEntry: current.isVoiceEntry,
        // For existing rich sections, if we edited the body text directly, we might just update the content field.
        // If it was purely generative, we leave the sections alone for now unless we implement full rich-text editing.
        sections: current.sections,
      );
      appState.updateEntry(entryToSave);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Entry saved!',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppColors.accentSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(entry),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildFormattingToolbar(),
                    const SizedBox(height: 16),
                    if (_showAiSuggestion) _buildAiSuggestionCard(),
                    const SizedBox(height: 20),
                    _buildRichContent(entry),
                    const SizedBox(height: 24),
                    _buildPhotoPlaceholder(),
                    const SizedBox(height: 24),
                    _buildMetadataFooter(entry),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(JournalEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(
              Icons.arrow_back_ios_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          // Title + Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entry Editor',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'May 23, 2026 — 2:34 PM',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Play button
          GestureDetector(
            onTap: _toggleTts,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isPlayingVoice ? AppColors.accentWarm : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isPlayingVoice ? 'Stop 🛑' : 'Play 🔊',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isPlayingVoice ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // Save button
          GestureDetector(
            onTap: () => _saveEntry(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Save ✓',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FORMATTING TOOLBAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFormattingToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Wrap(
          spacing: 6,
          children: List.generate(_toolbarLabels.length, (index) {
            final isActive = _activeToolbarIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _activeToolbarIndex = isActive ? -1 : index;
                });
                // '📷' → Photo Picker (index 7)
                if (index == 7) {
                  _pickAndUploadImage();
                }
                // 'Aa' → Typography Sheet (index 8)
                if (index == 8) {
                  _showTypographySheet();
                }
                // '🎨' → Theme Selector Sheet (index 9)
                if (index == 9) {
                  _showThemeSelectorSheet();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accentPrimary : AppColors.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isActive
                        ? AppColors.accentPrimary
                        : AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Text(
                  _toolbarLabels[index],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight:
                        (index == 0) ? FontWeight.w700 : FontWeight.w500,
                    fontStyle:
                        (index == 1) ? FontStyle.italic : FontStyle.normal,
                    decoration:
                        (index == 2) ? TextDecoration.underline : null,
                    color: isActive
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AI SUGGESTION CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAiSuggestionCard() {
    return SlideTransition(
      position: _aiSlideAnimation,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // Glassmorphism: slightly transparent surface
          color: AppColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.4),
            width: 1,
            // Dashed border simulation: we overlay a custom paint
          ),
          boxShadow: AppShadows.glow,
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.accentPrimary.withValues(alpha: 0.5),
            radius: 12,
            dashWidth: 6,
            dashSpace: 4,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI: This looks like a heading. Make it H2?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // Apply AI suggestion
                    _dismissAiSuggestion();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _dismissAiSuggestion,
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RICH TEXT CONTENT AREA
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRichContent(JournalEntry entry) {
    if (_isNewEntry) {
      // Editable fields for a new entry
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            decoration: InputDecoration(
              hintText: 'Entry Title...',
              hintStyle: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bodyController,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
            decoration: InputDecoration(
              hintText: 'Start writing your entry here...',
              hintStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
        ],
      );
    }

    // Render read-only sections for an existing voice-generated entry
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Entry Title
        Text(
          entry.title,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 20),
        // Render each section
        ..._sections.map(_buildSection),
      ],
    );
  }

  Widget _buildSection(EntrySection section) {
    switch (section.type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            section.content,
            style: GoogleFonts.inter(
              fontSize: section.headingLevel == 1 ? 22 : 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        );

      case 'paragraph':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            section.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
        );

      case 'bullet':
        return Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•  ',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimary,
                  height: 1.7,
                ),
              ),
              Expanded(
                child: Text(
                  section.content,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'quote':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: AppColors.accentWarm,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              section.content,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
                height: 1.7,
              ),
            ),
          ),
        );

      case 'photo':
        return _buildPhotoPlaceholder(label: section.content);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhotoPlaceholder({String label = '📷 Photo'}) {
    Widget content;
    if (label.startsWith('http')) {
      content = Image.network(
        label,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackBox('Error loading image'),
      );
    } else {
      content = _buildFallbackBox(label);
    }

    // Apply the selected photo frame
    Widget framedContent = content;
    switch (_selectedPhotoFrame) {
      case 'Polaroid':
        framedContent = Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          child: AspectRatio(
            aspectRatio: 4/5,
            child: content,
          ),
        );
        break;
      case 'Circle':
        framedContent = ClipOval(
          child: AspectRatio(
            aspectRatio: 1,
            child: content,
          ),
        );
        break;
      case 'Heart':
        framedContent = ClipPath(
          clipper: _HeartClipper(),
          child: AspectRatio(
            aspectRatio: 1,
            child: content,
          ),
        );
        break;
      default:
        framedContent = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: content,
        );
    }

    return GestureDetector(
      onLongPress: _showPhotoFrameSheet,
      onTap: () {
        if (label.startsWith('http')) {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  extendBodyBehindAppBar: true,
                  body: Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.network(label),
                    ),
                  ),
                );
              },
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: framedContent,
      ),
    );
  }

  Widget _buildFallbackBox(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // METADATA FOOTER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMetadataFooter(JournalEntry entry) {
    final chips = <String>[
      '😌 Nostalgic',
      '🌡 ${entry.temperature?.toInt() ?? 24}°C',
      '📍 ${entry.location ?? 'Campus'}',
      '⏱ ${entry.durationMinutes} min',
      if (entry.isVoiceEntry) '🎙 Voice',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((chip) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: Text(
              chip,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PHOTO FRAME SHEET
  // ═══════════════════════════════════════════════════════════════
  void _showPhotoFrameSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Photo Frame',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _photoFrames.map((frame) {
                      final isSelected = _selectedPhotoFrame == frame;
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() => _selectedPhotoFrame = frame);
                          setState(() => _selectedPhotoFrame = frame);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentPrimary : AppColors.bgSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.accentPrimary : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            frame,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TYPOGRAPHY SHEET
  // ═══════════════════════════════════════════════════════════════
  void _showTypographySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return DraggableScrollableSheet(
              maxChildSize: 0.7,
              initialChildSize: 0.65,
              minChildSize: 0.3,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 12),
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        'Typography',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Section 1: Font Selector ───
                      Text(
                        'Font Family',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _fontNames.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final isSelected = _selectedFontIndex == i;
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() => _selectedFontIndex = i);
                                setState(() {});
                              },
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accentPrimary
                                        : AppColors.borderSubtle,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Aa',
                                            style: _getFontStyle(i).copyWith(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _fontNames[i],
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: AppColors.accentPrimary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Section 2: Style Presets ───
                      Text(
                        'Style Presets',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: _stylePresets.length,
                        itemBuilder: (_, i) {
                          final isSelected = _selectedStyleIndex == i;
                          final preset = _stylePresets[i];
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() => _selectedStyleIndex = i);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentPrimary.withValues(alpha: 0.08)
                                    : AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accentPrimary
                                      : AppColors.borderSubtle,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        preset['name']!,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        preset['desc']!,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i == 0)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentPrimary,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '✨ AI Pick',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ─── Section 3: Font Size Slider ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Font Size',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${_fontSize.toInt()}px',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _fontSize,
                        min: 12,
                        max: 24,
                        divisions: 12,
                        activeColor: AppColors.accentPrimary,
                        inactiveColor: AppColors.borderSubtle,
                        onChanged: (v) {
                          setSheetState(() => _fontSize = v);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      // ─── Section 4: Line Height Slider ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Line Height',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _lineHeight.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _lineHeight,
                        min: 1.2,
                        max: 2.0,
                        divisions: 8,
                        activeColor: AppColors.accentPrimary,
                        inactiveColor: AppColors.borderSubtle,
                        onChanged: (v) {
                          setSheetState(() => _lineHeight = v);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  TextStyle _getFontStyle(int index) {
    switch (index) {
      case 0:
        return GoogleFonts.inter();
      case 1:
        return GoogleFonts.merriweather();
      case 2:
        return GoogleFonts.caveat();
      case 3:
        return GoogleFonts.jetBrainsMono();
      case 4:
        return GoogleFonts.playfairDisplay();
      default:
        return GoogleFonts.inter();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // THEME SELECTOR SHEET
  // ═══════════════════════════════════════════════════════════════
  void _showThemeSelectorSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return DraggableScrollableSheet(
              maxChildSize: 0.7,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 12),
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Theme',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a writing atmosphere',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Group by category
                      ..._buildThemeCategories(setSheetState),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildThemeCategories(StateSetter setSheetState) {
    // Group themes by category
    final categories = <String, List<int>>{};
    for (var i = 0; i < _themeCards.length; i++) {
      final cat = _themeCards[i].category;
      categories.putIfAbsent(cat, () => []);
      categories[cat]!.add(i);
    }

    final widgets = <Widget>[];
    for (final entry in categories.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Text(
            entry.key,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
      widgets.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 160 / 170,
          ),
          itemCount: entry.value.length,
          itemBuilder: (_, i) {
            final themeIdx = entry.value[i];
            final theme = _themeCards[themeIdx];
            final isSelected = _selectedThemeIndex == themeIdx;

            return GestureDetector(
              onTap: () async {
                final isPremium = context.read<AppState>().isPremium;
                if (theme.isPremium && !isPremium) {
                  final purchased = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                  if (purchased != true) return; // Didn't buy, don't apply theme
                }
                setSheetState(() => _selectedThemeIndex = themeIdx);
                setState(() {});
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderSubtle,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Preview area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.bgColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(13),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Preview text lines
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 70,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: theme.textColor.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 100,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: theme.textColor.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 80,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: theme.textColor.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 90,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: theme.textColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Premium lock
                            if (theme.isPremium)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            // Applied checkmark
                            if (isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Title area
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(13),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              theme.name,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Text(
                              'Applied',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accentPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return widgets;
  }
}

// ═══════════════════════════════════════════════════════════════
// DASHED BORDER PAINTER
// ═══════════════════════════════════════════════════════════════

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 12,
    this.dashWidth = 6,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashSpace != dashSpace;
}

// ═══════════════════════════════════════════════════════════════
// THEME CARD DATA
// ═══════════════════════════════════════════════════════════════

class _ThemeCard {
  final String name;
  final String category;
  final Color bgColor;
  final Color textColor;
  final bool isPremium;

  const _ThemeCard(
    this.name,
    this.category,
    this.bgColor,
    this.textColor,
    this.isPremium,
  );
}

// ═══════════════════════════════════════════════════════════════
// HEART CLIPPER
// ═══════════════════════════════════════════════════════════════

class _HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    path.moveTo(width / 2, height / 5);
    path.cubicTo(5 * width / 14, 0, 0, height / 15, width / 28, 2 * height / 5);
    path.cubicTo(width / 14, 2 * height / 3, 3 * width / 7, 5 * height / 6, width / 2, height);
    path.cubicTo(4 * width / 7, 5 * height / 6, 13 * width / 14, 2 * height / 3, 27 * width / 28, 2 * height / 5);
    path.cubicTo(width, height / 15, 9 * width / 14, 0, width / 2, height / 5);
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
