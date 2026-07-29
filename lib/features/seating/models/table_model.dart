import 'package:freezed_annotation/freezed_annotation.dart';

part 'table_model.freezed.dart';
part 'table_model.g.dart';

@freezed
class TableLayout with _$TableLayout {
  const factory TableLayout({
    required int tableNo,
    required List<SeatPosition> seats,
  }) = _TableLayout;

  factory TableLayout.fromJson(Map<String, dynamic> json) => _$TableLayoutFromJson(json);
}

@freezed
class SeatPosition with _$SeatPosition {
  const factory SeatPosition({
    required int seatNo,
    required double x,
    required double y,
    required String label,
  }) = _SeatPosition;

  factory SeatPosition.fromJson(Map<String, dynamic> json) => _$SeatPositionFromJson(json);
}

class TableModel {
  final String id;
  final int tableNumber;
  final List<SeatModel> seats;
  final bool isFinalTable;

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.seats,
    this.isFinalTable = false,
  });

  TableModel copyWith({
    String? id,
    int? tableNumber,
    List<SeatModel>? seats,
    bool? isFinalTable,
  }) {
    return TableModel(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      seats: seats ?? this.seats,
      isFinalTable: isFinalTable ?? this.isFinalTable,
    );
  }
}

class SeatModel {
  final int seatNumber;
  final bool isOccupied;
  final String? playerName;

  SeatModel({
    required this.seatNumber,
    required this.isOccupied,
    this.playerName,
  });

  SeatModel copyWith({
    int? seatNumber,
    bool? isOccupied,
    String? playerName,
  }) {
    return SeatModel(
      seatNumber: seatNumber ?? this.seatNumber,
      isOccupied: isOccupied ?? this.isOccupied,
      playerName: playerName ?? this.playerName,
    );
  }
}
