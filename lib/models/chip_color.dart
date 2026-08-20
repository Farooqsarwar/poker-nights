import 'package:flutter/material.dart';

/// A poker chip denomination and its physical colour.
class ChipColor {
  const ChipColor({
    required this.color,
    required this.hex,
    required this.value,
    required this.quantity,
  });

  final String color;
  final int hex;
  final int value;
  final int quantity;

  Color get colorValue => Color(hex);

  ChipColor copyWith({String? color, int? hex, int? value, int? quantity}) {
    return ChipColor(
      color: color ?? this.color,
      hex: hex ?? this.hex,
      value: value ?? this.value,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChipColor &&
      other.color == color &&
      other.hex == hex &&
      other.value == value &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(color, hex, value, quantity);
}
