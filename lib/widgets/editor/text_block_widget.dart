import 'package:flutter/material.dart';
import '../../models/memory_block.dart';
import '../../theme/app_theme.dart';

class TextBlockWidget extends StatefulWidget {
  final TextBlock block;
  final VoidCallback onAddBlockRequested;
  final VoidCallback onRemoveRequested;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const TextBlockWidget({
    super.key,
    required this.block,
    required this.onAddBlockRequested,
    required this.onRemoveRequested,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = AppType.of(context);
    final bodyStyle = type.readingBody.copyWith(
      fontSize: 16,
      color: colors.text,
      height: 1.75,
      letterSpacing: 0.1,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: bodyStyle,
        decoration: InputDecoration(
          hintText: widget.block.text.isEmpty ? 'Begin here...' : '',
          hintStyle: bodyStyle.copyWith(color: colors.textFaint),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (value) {
          widget.block.text = value;
          widget.onChanged?.call(value);
          if (value.endsWith('\n\n')) {
            widget.block.text = value.substring(0, value.length - 2);
            _controller.value = _controller.value.copyWith(
              text: widget.block.text,
              selection: TextSelection.collapsed(
                offset: widget.block.text.length,
              ),
            );
            widget.onAddBlockRequested();
          }
        },
      ),
    );
  }
}
