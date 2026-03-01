import 'package:flutter/material.dart';

import '../config/theme.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubtitle;
  final bool Function(T, String) filter;
  final ValueChanged<T?> onSelected;
  final String? Function(T?)? validator;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.selectedItem,
    required this.itemLabel,
    this.itemSubtitle,
    required this.filter,
    required this.onSelected,
    this.validator,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _isOpen = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selectedItem != null
          ? widget.itemLabel(widget.selectedItem as T)
          : '',
    );
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _isOpen = true);
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _isOpen = false);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem != oldWidget.selectedItem) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.text = widget.selectedItem != null
              ? widget.itemLabel(widget.selectedItem as T)
              : '';
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    if (_query.isEmpty) return widget.items;
    return widget.items.where((item) => widget.filter(item, _query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator: (_) => widget.validator?.call(widget.selectedItem),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                suffixIcon: widget.selectedItem != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          widget.onSelected(null);
                          setState(() => _query = '');
                        },
                      )
                    : const Icon(Icons.arrow_drop_down),
                errorText: state.errorText,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            if (_isOpen && _filteredItems.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredItems.length,
                  itemBuilder: (ctx, i) {
                    final item = _filteredItems[i];
                    final isSelected = widget.selectedItem != null &&
                        widget.itemLabel(widget.selectedItem as T) ==
                            widget.itemLabel(item);
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      title: Text(widget.itemLabel(item),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: widget.itemSubtitle != null
                          ? Text(widget.itemSubtitle!(item),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryOf(context)))
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              size: 18,
                              color: Theme.of(context).primaryColor)
                          : null,
                      onTap: () {
                        widget.onSelected(item);
                        _controller.text = widget.itemLabel(item);
                        _focusNode.unfocus();
                        setState(() {
                          _query = '';
                          _isOpen = false;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
