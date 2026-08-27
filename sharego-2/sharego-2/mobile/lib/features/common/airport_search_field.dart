import 'package:flutter/material.dart';

import '../../core/airport_repository.dart';
import '../../core/app_theme.dart';

class AirportSearchField extends StatefulWidget {
  const AirportSearchField({
    super.key,
    required this.repository,
    required this.onSelected,
    this.initialIata,
    this.label = 'Airport',
    this.enabled = true,
  });

  final AirportRepository repository;
  final ValueChanged<Airport> onSelected;
  final String? initialIata;
  final String label;
  final bool enabled;

  @override
  State<AirportSearchField> createState() => _AirportSearchFieldState();
}

class _AirportSearchFieldState extends State<AirportSearchField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIata != null
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
    return Autocomplete<Airport>(
      optionsBuilder: (textEditingValue) {
        if (!widget.enabled) return const Iterable<Airport>.empty();
        return widget.repository.search(textEditingValue.text.trim());
      },
      displayStringForOption: (airport) => airport.displayLabel,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync initial value on first build.
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
            hintText: 'Search airport or city...',
            hintStyle: const TextStyle(fontSize: 12),
            isDense: true,
            prefixIcon: const Icon(Icons.flight, size: 18),
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
                  final airport = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(airport),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Text(
                            airport.iata,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${airport.city}, ${airport.country}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
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
      onSelected: (airport) {
        widget.onSelected(airport);
      },
    );
  }
}
