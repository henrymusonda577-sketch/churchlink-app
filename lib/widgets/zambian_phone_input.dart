import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ZambianPhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  const ZambianPhoneInput({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText = '771 234 567',
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<ZambianPhoneInput> createState() => _ZambianPhoneInputState();
}

class _ZambianPhoneInputState extends State<ZambianPhoneInput> {
  String? _validationError;

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 9) {
      return 'Phone number must be exactly 9 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _validationError != null ? Colors.red : Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Zambian flag and country code (fixed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🇿🇲', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '+260',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Phone number input (9 digits only)
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    counterText: '',
                    errorStyle: const TextStyle(height: 0), // Hide error text here
                  ),
                  onChanged: (value) {
                    setState(() {
                      _validationError = _validatePhone(value);
                    });
                    widget.onChanged?.call(value);
                  },
                  validator: (value) {
                    final error = _validatePhone(value);
                    if (error != null) {
                      setState(() => _validationError = error);
                      return error;
                    }
                    setState(() => _validationError = null);
                    return widget.validator?.call(value);
                  },
                ),
              ),
            ],
          ),
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 4),
          Text(
            _validationError!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}