import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Voice State
//
// Focus: Managing the speech-to-text lifecycle, mic status,
// and the reflection processing steps.
// ═══════════════════════════════════════════════════════════════

class VoiceState extends ChangeNotifier {
  // ─── Recording State ───
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  void setRecording(bool value) {
    _isRecording = value;
    notifyListeners();
  }

  // ─── Processing State ───
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  
  double _processingProgress = 0.0;
  double get processingProgress => _processingProgress;
  
  String _processingStep = '';
  String get processingStep => _processingStep;
  
  String? _processingError;
  String? get processingError => _processingError;

  void setProcessingState({
    required bool isProcessing,
    double progress = 0.0,
    String step = '',
    String? error,
  }) {
    _isProcessing = isProcessing;
    _processingProgress = progress;
    _processingStep = step;
    _processingError = error;
    notifyListeners();
  }

  void resetProcessing() {
    _isProcessing = false;
    _processingProgress = 0.0;
    _processingStep = '';
    _processingError = null;
    notifyListeners();
  }
}
