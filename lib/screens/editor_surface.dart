import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

import '../models/memory_block.dart';
import '../models/models.dart';
import '../state/memory_state.dart';
import '../state/preferences_state.dart';
import '../state/memory_persistence_state.dart';
import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import '../widgets/editor/reflection_block_widget.dart';
import '../widgets/editor/text_block_widget.dart';
import '../widgets/editor/voice_block_widget.dart';
import '../widgets/editor/voice_recorder_widget.dart';
import '../services/voice_recording_service.dart';
import '../services/narration_service.dart';
import '../services/auth_service.dart';
import '../services/outbox_service.dart';
import '../services/paywall_service.dart';
import 'paywall_sheet.dart';

class EditorSurface extends StatefulWidget {
  final JournalEntry? initialEntry;

  const EditorSurface({super.key, this.initialEntry});

  @override
  State<EditorSurface> createState() => _EditorSurfaceState();
}

class _EditorSurfaceState extends State<EditorSurface> with TickerProviderStateMixin {
  late JournalEntry _entry;
  late TextEditingController _titleController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, FocusNode> _focusNodes = {};
  bool _hasUnsavedChanges = false;
  String _saveStatus = '';

  // Phase 2 Progressive controls tracking
  Timer? _idleTimer;
  Timer? _autosaveTimer;
  bool _showControls = true;
  double _lastOffset = 0.0;

  // Animation & Focus for Title and Done button
  bool _isShimmering = false;
  late final AnimationController _titleColorController;
  late final Animation<double> _titleColorProgress;
  late final FocusNode _titleFocusNode;
  String _lastTitleText = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialEntry != null) {
      _entry = widget.initialEntry!;
      if (_entry.blocks.isEmpty && _entry.content.isNotEmpty) {
        _entry = _entry.copyWith(blocks: [TextBlock(text: _entry.content)]);
      }
    } else {
      _entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '',
        content: '',
        blocks: [TextBlock()],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: Mood.neutral,
      );
    }

    _titleController = TextEditingController(text: _entry.title);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _lastTitleText = _entry.title;

    _titleColorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _titleColorProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleColorController, curve: Curves.easeIn),
    );
    if (_entry.title.isNotEmpty) {
      _titleColorController.value = 1.0;
    }

    _titleController.addListener(() {
      _onKeyPress();
      final text = _titleController.text;
      if (_lastTitleText.isEmpty && text.isNotEmpty) {
        _titleColorController.forward(from: 0.0);
      } else if (text.isEmpty && _lastTitleText.isNotEmpty) {
        _titleColorController.reverse(from: 1.0);
      }
      _lastTitleText = text;
      if (mounted) setState(() {});
    });

    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if (offset <= 10.0) {
        if (!_showControls) setState(() => _showControls = true);
        _idleTimer?.cancel();
      } else {
        if (offset < _lastOffset && (offset - _lastOffset).abs() > 5) {
          if (!_showControls) setState(() => _showControls = true);
          _resetIdleTimer();
        } else if (offset > _lastOffset && (offset - _lastOffset).abs() > 5) {
          if (_showControls) setState(() => _showControls = false);
          _idleTimer?.cancel();
        }
      }
      _lastOffset = offset;
    });

    _startAutosaveLoop();
  }

  void _startAutosaveLoop() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_hasUnsavedChanges && mounted) {
        _autosaveDraft();
      }
    });
  }

  Future<void> _autosaveDraft() async {
    final title = _titleController.text;
    final content = _entry.blocks
        .whereType<TextBlock>()
        .map((block) => block.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    final hasVoiceBlocks = _entry.blocks.any((b) => b is VoiceBlock);

    if (title.trim().isEmpty && content.trim().isEmpty && !hasVoiceBlocks) return;

    if (mounted) setState(() => _saveStatus = 'saving...');

    final draftJson = jsonEncode({
      'entry': _entry.copyWith(
        title: title,
        content: content,
        updatedAt: DateTime.now(),
      ).toMap(),
      'blocks': _entry.blocks.map((b) => b.toJson()).toList(),
      'isExistingEntry': widget.initialEntry != null,
    });

    // FIX: use the bool return to know if the write actually succeeded.
    final succeeded = await context.read<MemoryPersistenceState>().saveDraft(draftJson);
    _hasUnsavedChanges = !succeeded;
    if (mounted) {
      setState(() {
        _saveStatus = succeeded ? 'saved just now' : 'unsaved changes';
      });
    }
  }

  void _onKeyPress() {
    _hasUnsavedChanges = true;
    if (_saveStatus != 'unsaved changes') {
      setState(() => _saveStatus = 'unsaved changes');
    }
    _idleTimer?.cancel();
    // ── FIX: Don't hide controls while typing — only secondary actions fade ──
    // The Done button must always be tappable so user never loses work.
    // We keep the controls visible; the idle timer is still used for scroll-hide logic.
    _idleTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showControls = true);
    });
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _scrollController.hasClients && _scrollController.offset > 10.0) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _autosaveTimer?.cancel();

    // ── FIX: Schedule the draft flush as a microtask so it fires
    //   before the context is fully torn down, giving SQLite a chance
    //   to complete the write before the widget tree is destroyed. ──
    if (_hasUnsavedChanges) {
      final title = _titleController.text;
      final content = _entry.blocks
          .whereType<TextBlock>()
          .map((block) => block.text.trim())
          .where((text) => text.isNotEmpty)
          .join('\n\n');
      final hasVoiceBlocks = _entry.blocks.any((b) => b is VoiceBlock);
      if (title.trim().isNotEmpty || content.trim().isNotEmpty || hasVoiceBlocks) {
        final draftJson = jsonEncode({
          'entry': _entry.copyWith(
            title: title,
            content: content,
            updatedAt: DateTime.now(),
          ).toMap(),
          'blocks': _entry.blocks.map((b) => b.toJson()).toList(),
          'isExistingEntry': widget.initialEntry != null,
        });
        // Use unawaited but keep a reference so the future isn't GC'd:
        final persistState = context.read<MemoryPersistenceState>();
        Future.microtask(() => persistState.saveDraft(draftJson));
      }
    }

    _titleColorController.dispose();
    _titleFocusNode.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    // Stop narration quietly if it was playing for this entry
    try {
      final narration = context.read<NarrationService>();
      if (narration.currentEntryId == _entry.id) {
        narration.stop();
      }
    } catch (_) {}
    super.dispose();
  }

  FocusNode _getNode(String id) {
    return _focusNodes.putIfAbsent(id, FocusNode.new);
  }

  void _addTextBlockAfter(int index) {
    final newBlock = TextBlock();
    setState(() {
      final newBlocks = List<MemoryBlock>.of(_entry.blocks);
      newBlocks.insert(index + 1, newBlock);
      _entry = _entry.copyWith(blocks: newBlocks);
      _hasUnsavedChanges = true;
      _saveStatus = 'unsaved changes';
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _getNode(newBlock.id).requestFocus();
    });
  }

  void _removeBlock(int index) {
    if (_entry.blocks.length <= 1) return;
    setState(() {
      final newBlocks = List<MemoryBlock>.of(_entry.blocks);
      final removed = newBlocks.removeAt(index);
      _focusNodes[removed.id]?.dispose();
      _focusNodes.remove(removed.id);
      _entry = _entry.copyWith(blocks: newBlocks);
      _hasUnsavedChanges = true;
      _saveStatus = 'unsaved changes';
      if (index > 0) {
        _getNode(newBlocks[index - 1].id).requestFocus();
      }
    });
  }

  void _openVoiceRecorder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => VoiceRecordingService(),
        child: VoiceRecorderWidget(
          onTranscriptReady: (transcript) {
            setState(() {
              final newBlocks = List<MemoryBlock>.of(_entry.blocks)
                ..add(TextBlock(text: transcript));
              _entry = _entry.copyWith(blocks: newBlocks);
              _hasUnsavedChanges = true;
              _saveStatus = 'unsaved changes';
            });
            _autosaveDraft(); // Trigger immediate save when voice block lands
          },
        ),
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    final paywall = context.read<PaywallService>();
    final gate = paywall.checkGate(ProFeature.unlimitedMedia);
    if (gate != null) {
      final unlocked = await PaywallSheet.show(context, gate);
      if (!unlocked) return;
    }

    try {
      final picker = ImagePicker();
      XFile? image;
      try {
        AuthService().setImagePickerInProgress(true);
        image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
        );
        if (image == null) return;
        
        setState(() {
          _entry = _entry.copyWith(thumbnailPath: image!.path);
          _hasUnsavedChanges = true;
          _saveStatus = 'unsaved changes';
        });
      } finally {
        AuthService().setImagePickerInProgress(false);
      }
      _autosaveDraft(); // Trigger immediate save when photo is picked
    } catch (e) {
      debugPrint('[Editor] failed to pick image: $e');
    }
  }

  void _removeThumbnail() {
    setState(() {
      _entry = _entry.copyWith(clearThumbnail: true);
      _hasUnsavedChanges = true;
      _saveStatus = 'unsaved changes';
    });
  }

  void _pickLocation() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit location',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 22,
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.my_location_rounded, color: colors.accent),
              title: Text(
                'Use my current location',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colors.text,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final isPremium = context.read<PreferencesState>().isPremium;
                final memoryState = context.read<MemoryState>();
                final hasExistingLocation = _entry.latitude != null && _entry.longitude != null;
                if (!isPremium && !hasExistingLocation && memoryState.locations.length >= 5) {
                  await PaywallSheet.show(context, ProFeature.mapView);
                  return;
                }
                final loc = await _captureLocation();
                if (loc == null) return;
                setState(() {
                  _entry = _entry.copyWith(
                    latitude: loc.lat,
                    longitude: loc.lng,
                    locationLabel: loc.label,
                  );
                  _hasUnsavedChanges = true;
                  _saveStatus = 'unsaved changes';
                });
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_off_outlined, color: Colors.redAccent),
              title: const Text(
                'Remove location',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                setState(() {
                  _entry = _entry.copyWith(clearLocation: true);
                  _hasUnsavedChanges = true;
                  _saveStatus = 'unsaved changes';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<LatLngLabel?> _captureLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final place = placemarks.firstOrNull;
      final label = [place?.locality, place?.administrativeArea]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      return LatLngLabel(pos.latitude, pos.longitude, label);
    } catch (e) {
      debugPrint('[Location] capture failed: $e');
      return null;
    }
  }

  Future<void> _saveAndExit() async {
    if (_saveStatus == 'saving...') return;
    AppHaptics.light();

    if (mounted) setState(() => _saveStatus = 'saving...');

    final content = _entry.blocks
        .whereType<TextBlock>()
        .map((block) => block.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    final title = _titleController.text.trim();
    final hasVoiceBlocks = _entry.blocks.any((b) => b is VoiceBlock);

    LatLngLabel? loc;
    if (_entry.latitude == null) {
      loc = await _captureLocation();
    }

    final updatedEntry = _entry.copyWith(
      title: title.isEmpty ? 'Untitled Memory' : title,
      content: content,
      updatedAt: DateTime.now(),
      latitude: loc != null ? loc.lat : _entry.latitude,
      longitude: loc != null ? loc.lng : _entry.longitude,
      locationLabel: loc != null ? loc.label : _entry.locationLabel,
    );

    final memoryState = context.read<MemoryState>();
    final persistState = context.read<MemoryPersistenceState>();
    final exists = memoryState.entries.any((entry) => entry.id == updatedEntry.id);

    // ── FIX: Wrap in try/catch so failures are visible and don't silently lose data ──
    try {
      if (exists) {
        await memoryState.updateEntry(updatedEntry);
      } else if (content.isNotEmpty || title.isNotEmpty || hasVoiceBlocks) {
        await memoryState.addEntry(updatedEntry);
      }
    } catch (e) {
      debugPrint('[Editor] _saveAndExit failed: $e');
      if (mounted) {
        setState(() => _saveStatus = 'save failed — try again');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this memory. Please try again.',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return; // ← Stay in editor — don't pop and lose unsaved work
    }

    // Push to Supabase in background via outbox
    final authService = context.read<AuthService>();
    if (authService.isSignedIn) {
      unawaited(() async {
        try {
          await OutboxService().processQueue();
        } catch (e) {
          debugPrint('[Editor] background sync failed: $e');
        }
      }());
    }

    await persistState.clearDraft();
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _saveStatus = 'saved';
        _isShimmering = true;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _dismiss() {
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefs = context.watch<PreferencesState>();
    final type = AppType.of(context, fontOverride: prefs.selectedFont);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final persistState = context.read<MemoryPersistenceState>();
        final colors = AppColors.of(context);
        final action = await showDialog<String>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.hairline, width: 0.5),
            ),
            title: Text(
              'Unsaved Changes',
              style: TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            content: Text(
              'Would you like to save this reflection before leaving?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.redAccent, fontFamily: 'Inter', fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.textSecondary, fontFamily: 'Inter', fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: Text(
                  'Save',
                  style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13),
                ),
              ),
            ],
          ),
        );

        if (action == 'save') {
          await _saveAndExit();
        } else if (action == 'discard') {
          // Clear active draft and allow popping without another intercept
          await persistState.clearDraft();
          if (context.mounted) {
            setState(() {
              _hasUnsavedChanges = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Background film grain
            const Positioned.fill(
              child: IgnorePointer(
                child: CinematicGrain(seed: 13, animate: false),
              ),
            ),
            
            // Continuous scrollable writing canvas
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 64, 28, 120), // top padding to push text below overlay controls
                  itemCount: _entry.blocks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Thumbnail header image
                          if (_entry.thumbnailPath != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: (_entry.thumbnailPath!.startsWith('http://') || _entry.thumbnailPath!.startsWith('https://'))
                                        ? Image.network(
                                            _entry.thumbnailPath!,
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                          )
                                        : Image.file(
                                            File(_entry.thumbnailPath!),
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                          ),
                                  ),
                                  // Friendly local storage reminder for free users
                                  if (!prefs.isPremium &&
                                      _entry.thumbnailPath != null &&
                                      !_entry.thumbnailPath!.startsWith('http://') &&
                                      !_entry.thumbnailPath!.startsWith('https://'))
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.7),
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                        ),
                                        child: Text(
                                          'Saved to this device. Back up to the cloud with Antheia Pro.',
                                          style: TextStyle(
                                            fontFamily: 'Cormorant Garamond',
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12.5,
                                            color: Colors.white.withValues(alpha: 0.9),
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  // Remove thumbnail X button
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: _removeThumbnail,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Location chip
                          if (_entry.locationLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: _pickLocation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: colors.hairline, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_on_outlined,
                                            size: 13, color: colors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          _entry.locationLabel!,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit_outlined,
                                            size: 11, color: colors.textFaint),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                AnimatedBuilder(
                                  animation: _titleController,
                                  builder: (context, _) {
                                    final showPlaceholder = _titleController.text.isEmpty && !_titleFocusNode.hasFocus;
                                    return AnimatedOpacity(
                                      opacity: showPlaceholder ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      child: IgnorePointer(
                                        child: Text(
                                          'Untitled',
                                          style: type.readingTitle.copyWith(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w300,
                                            color: colors.textFaint,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                AnimatedBuilder(
                                  animation: _titleColorProgress,
                                  builder: (context, _) {
                                    final textColor = Color.lerp(
                                      colors.textFaint,
                                      colors.text,
                                      _titleColorProgress.value,
                                    );
                                    return TextField(
                                      controller: _titleController,
                                      focusNode: _titleFocusNode,
                                      style: type.readingTitle.copyWith(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w500,
                                        color: textColor ?? colors.text,
                                        height: 1.25,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textCapitalization: TextCapitalization.sentences,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    final blockIndex = index - 1;
                    final block = _entry.blocks[blockIndex];

                    if (block is TextBlock) {
                      return TextBlockWidget(
                        block: block,
                        focusNode: _getNode(block.id),
                        onAddBlockRequested: () =>
                            _addTextBlockAfter(blockIndex),
                        onRemoveRequested: () => _removeBlock(blockIndex),
                        onChanged: (val) => _onKeyPress(),
                      );
                    }
                    if (block is VoiceBlock) {
                      return VoiceBlockWidget(
                        block: block,
                        onTranscriptChanged: (newTranscript) {
                          setState(() {
                            block.transcript = newTranscript;
                            _hasUnsavedChanges = true;
                            _saveStatus = 'unsaved changes';
                          });
                          _autosaveDraft(); // Trigger immediate save when transcript changes
                        },
                      );
                    }
                    if (block is ReflectionBlock) {
                      return ReflectionBlockWidget(block: block);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            
            // Progressive Navigation Controls Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // ── FIX: Removed IgnorePointer wrapping.
              // The Done button must ALWAYS be tappable.
              // Controls now fade to 15% instead of disappearing,
              // so the user always knows it's there and can tap it.
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.15,
                duration: Duration(milliseconds: _showControls ? 600 : 150),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AnimationScale.of(context) == AnimationIntensity.stillness ? 0 : 16,
                      sigmaY: AnimationScale.of(context) == AnimationIntensity.stillness ? 0 : 16,
                      tileMode: TileMode.decal,
                    ),
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? colors.bg.withValues(alpha: 0.65)
                          : colors.bg.withValues(alpha: 0.55),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SafeArea(
                        bottom: false,
                        child: _FloatingControls(
                          onDismiss: _dismiss,
                          onSave: _saveAndExit,
                          onOpenVoice: _openVoiceRecorder,
                          onPickThumbnail: _pickThumbnail,
                          onRemoveThumbnail: _removeThumbnail,
                          thumbnailPath: _entry.thumbnailPath,
                          colors: colors,
                          type: type,
                          entryId: _entry.id,
                          title: _titleController.text,
                          saveStatus: _saveStatus,
                          isShimmering: _isShimmering,
                          content: _entry.blocks
                              .whereType<TextBlock>()
                              .map((block) => block.text.trim())
                              .where((text) => text.isNotEmpty)
                              .join('\n\n'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingControls extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onSave;
  final VoidCallback onOpenVoice;
  final VoidCallback onPickThumbnail;
  final VoidCallback onRemoveThumbnail;
  final String? thumbnailPath;
  final ResolvedColors colors;
  final ResolvedType type;
  final String entryId;
  final String title;
  final String content;
  final String saveStatus;
  final bool isShimmering;

  const _FloatingControls({
    required this.onDismiss,
    required this.onSave,
    required this.onOpenVoice,
    required this.onPickThumbnail,
    required this.onRemoveThumbnail,
    required this.thumbnailPath,
    required this.colors,
    required this.type,
    required this.entryId,
    required this.title,
    required this.content,
    required this.saveStatus,
    required this.isShimmering,
  });

  @override
  Widget build(BuildContext context) {
    final narration = context.watch<NarrationService>();
    final prefs = context.watch<PreferencesState>();
    final isCurrent = narration.currentEntryId == entryId;
    final isPlaying = isCurrent && narration.state == NarrationState.playing;
    final isPaused = isCurrent && narration.state == NarrationState.paused;

    return Padding(
      // ── FIX: Use symmetric padding so nothing bleeds off-screen ──
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Back arrow — always pinned left, never scrolled ──
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 13,
                color: colors.textFaint,
              ),
            ),
          ),

          // ── FIX: Middle actions in a horizontally scrollable strip ──
          // This prevents the Done button from being clipped on narrow
          // screens. The user can swipe left to access all actions.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              // Right-align content by reversing so "done" appears first
              // without scrolling, and secondary actions require a swipe.
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Done — rightmost, always first visible ──
                  _ShimmerDoneButton(
                    onTap: onSave,
                    isShimmering: isShimmering,
                    colors: colors,
                    type: type,
                  ),

                  const SizedBox(width: 4),

                  // ── Voice ──
                  GestureDetector(
                    onTap: onOpenVoice,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_none_rounded, size: 15, color: colors.textSecondary),
                          const SizedBox(width: 3),
                          Text('voice', style: type.small.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          )),
                        ],
                      ),
                    ),
                  ),

                  // ── Photo ──
                  GestureDetector(
                    onTap: onPickThumbnail,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            thumbnailPath != null ? Icons.photo_rounded : Icons.photo_outlined,
                            size: 15,
                            color: thumbnailPath != null ? colors.accent : colors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'photo',
                            style: type.small.copyWith(
                              color: thumbnailPath != null ? colors.accent : colors.textSecondary,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Narrate ── (only shown when there's content)
                  if (content.trim().isNotEmpty || title.trim().isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final paywall = context.read<PaywallService>();
                        final gate = paywall.checkGate(ProFeature.narration);
                        if (gate != null) {
                          await PaywallSheet.show(context, gate);
                          return;
                        }
                        if (isPlaying) {
                          narration.pause();
                        } else if (isPaused) {
                          narration.resume();
                        } else {
                          narration.speakEntry(
                            entryId,
                            title,
                            content,
                            speed: prefs.ttsSpeed,
                            pitch: prefs.ttsPitch,
                          );
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPlaying
                                  ? Icons.pause_circle_outline_rounded
                                  : (isPaused
                                      ? Icons.play_circle_outline_rounded
                                      : Icons.volume_up_outlined),
                              size: 15,
                              color: isPlaying ? colors.accent : colors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isPlaying ? 'listening' : 'narrate',
                              style: type.small.copyWith(
                                color: isPlaying ? colors.accent : colors.textSecondary,
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Autosave status ── (leftmost, fades away naturally)
                  if (saveStatus.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      saveStatus,
                      style: type.small.copyWith(
                        color: saveStatus == 'unsaved changes'
                            ? colors.error.withValues(alpha: 0.7)
                            : colors.textFaint,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple data class for location mapping
class LatLngLabel {
  final double lat, lng;
  final String label;
  LatLngLabel(this.lat, this.lng, this.label);
}

class _ShimmerDoneButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isShimmering;
  final ResolvedColors colors;
  final ResolvedType type;

  const _ShimmerDoneButton({
    required this.onTap,
    required this.isShimmering,
    required this.colors,
    required this.type,
  });

  @override
  State<_ShimmerDoneButton> createState() => _ShimmerDoneButtonState();
}

class _ShimmerDoneButtonState extends State<_ShimmerDoneButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant _ShimmerDoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShimmering && !oldWidget.isShimmering) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = AnimationScale.of(context).durationScale;
    if (scale == 0.0) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Text(
            'done',
            style: widget.type.small.copyWith(
              color: widget.colors.accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (!_controller.isAnimating) {
              return Text(
                'done',
                style: widget.type.small.copyWith(
                  color: widget.colors.accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
              );
            }

            return ShaderMask(
              shaderCallback: (bounds) {
                final double t = _controller.value;
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.colors.accent,
                    const Color(0xFFFFDF00),
                    widget.colors.accent,
                  ],
                  stops: [
                    (t - 0.45).clamp(0.0, 1.0),
                    t.clamp(0.0, 1.0),
                    (t + 0.45).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              child: Text(
                'done',
                style: widget.type.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
