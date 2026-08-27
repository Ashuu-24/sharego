import 'package:flutter/material.dart';

import '../../core/airline_repository.dart';
import '../../core/app_theme.dart';

class AirlineSearchField extends StatefulWidget {
  const AirlineSearchField({
    super.key,
    required this.repository,
    required this.onSelected,
    this.initialIata,
    this.label = 'Airline',
    this.enabled = true,
  });

  final AirlineRepository repository;
  final ValueChanged<Airline> onSelected;
  final String? initialIata;
  final String label;
  final bool enabled;

  @override
  State<AirlineSearchField> createState() => _AirlineSearchFieldState();
}

class _AirlineSearchFieldState extends State<AirlineSearchField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIata != null && widget.initialIata!.isNotEmpty
        ? widget.repository.byIata(widget.initialIata!)
        : null;
    _controller = TextEditingController(text: initial?.displayLabel ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Airline>(
      optionsBuilder: (textEditingValue) {
        if (!widget.enabled) return const Iterable<Airline>.empty();
        return widget.repository.search(textEditingValue.text.trim());
      },
      displayStringForOption: (airline) => airline.displayLabel,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (controller.text.isEmpty && _controller.text.isNotEmpty) {
          controller.text = _controller.text;
        }
        _controller = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(fontSize: 13),
            hintText: 'Search airline...',
            hintStyle: const TextStyle(fontSize: 12),
            isDense: true,
            prefixIcon: const Icon(Icons.airlines, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E2EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 1.4),
            ),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 340),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final airline = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(airline),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Text(
                            airline.iata,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  airline.name,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  airline.country,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey.shade500),
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
            ),
          ),
        );
      },
      onSelected: (airline) {
        widget.onSelected(airline);
      },
    );
  }
}
