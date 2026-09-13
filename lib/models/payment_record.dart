/// What a payment was for.
enum PaymentPurpose {
  buyIn,
  rebuy,
  reEntry,
  addOn;

  String get label => switch (this) {
        PaymentPurpose.buyIn => 'Buy-in',
        PaymentPurpose.rebuy => 'Rebuy',
        PaymentPurpose.reEntry => 'Re-entry',
        PaymentPurpose.addOn => 'Add-on',
      };
}

/// Where a payment attempt ended up.
enum PaymentStatus {
  /// Money (notionally) collected. Only this counts toward the prize pool.
  paid,

  /// The attempt failed. Recorded rather than discarded so a host can see
  /// that somebody tried and it did not go through.
  failed,

  /// Abandoned before completing.
  cancelled;

  String get label => switch (this) {
        PaymentStatus.paid => 'Paid',
        PaymentStatus.failed => 'Failed',
        PaymentStatus.cancelled => 'Cancelled',
      };

  bool get countsTowardPool => this == PaymentStatus.paid;
}

/// One recorded payment against a tournament.
///
/// **Simulated.** No money moves, no card is charged and no payment provider
/// is contacted — see `MockPaymentService`. The record exists so the
/// tournament's accounting, the prize pool and the host's view of who has
/// settled up all agree, which is the part that has to be right whether the
/// money moved through the app or across the table in cash.
///
/// [idempotencyKey] is what makes a double-tap safe. Two attempts carrying the
/// same key are the same payment, however many times the button was pressed or
/// the request was retried after a dropped connection.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.playerId,
    required this.purpose,
    required this.amount,
    required this.status,
    required this.timestamp,
    required this.idempotencyKey,
    this.failureReason,
  });

  final String id;
  final String playerId;
  final PaymentPurpose purpose;

  /// The amount configured for this purpose on the tournament, never a figure
  /// supplied by the payer — see `AppProvider.recordPayment`.
  final int amount;

  final PaymentStatus status;
  final DateTime timestamp;
  final String idempotencyKey;
  final String? failureReason;

  PaymentRecord copyWith({PaymentStatus? status, String? failureReason}) =>
      PaymentRecord(
        id: id,
        playerId: playerId,
        purpose: purpose,
        amount: amount,
        status: status ?? this.status,
        timestamp: timestamp,
        idempotencyKey: idempotencyKey,
        failureReason: failureReason ?? this.failureReason,
      );

  @override
  bool operator ==(Object other) =>
      other is PaymentRecord &&
      other.id == id &&
      other.playerId == playerId &&
      other.purpose == purpose &&
      other.amount == amount &&
      other.status == status &&
      other.idempotencyKey == idempotencyKey;

  @override
  int get hashCode =>
      Object.hash(id, playerId, purpose, amount, status, idempotencyKey);
}
