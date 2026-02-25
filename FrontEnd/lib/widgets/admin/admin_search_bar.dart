import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/theme.dart';

class AdminSearchBar extends StatefulWidget {
  const AdminSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.resultCount,
    this.totalCount,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final int? resultCount;
  final int? totalCount;

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.onChanged(value.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = widget.resultCount != null &&
        widget.totalCount != null &&
        widget.resultCount != widget.totalCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        widget.onChanged('');
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.sm,
                borderSide: BorderSide(color: AppTheme.dividerOf(context)),
              ),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.resultCount} of ${widget.totalCount} results',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
