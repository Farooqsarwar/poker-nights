/// AppProvider: simulated payments.
///
/// QA section 12. Nothing here moves money, charges a card or contacts a
/// payment provider — see [MockPaymentService]. What it does do is keep the
/// tournament's accounting honest: who has settled up, what reached the prize
/// pool, and what happened when an attempt failed.
///
/// The accounting has to be right whether the money went through the app or
/// across the table in cash, so this is deliberately a LEDGER rather than a
/// payment integration. Swapping the simulation for a real provider later
/// means writing one service; none of this changes.
part of 'app_provider.dart';

extension AppProviderPayments on AppProvider {
  /// The amount a purpose costs on this tournament.
  ///
  /// Taken from the tournament's own settings, never from the payer. QA case
  /// PN-NEG-013 ("manipulate dummy payment amount") is prevented here rather
  /// than by validating what the client sent — there is no amount to send.
  int amountFor(PaymentPurpose purpose) {
    final s = _currentGame?.settings;
    if (s == null) return 0;
    return switch (purpose) {
      PaymentPurpose.buyIn => s.buyIn,
      PaymentPurpose.rebuy => s.effectiveRebuyCost,
      // A re-entry buys a fresh entry, so it costs a buy-in (section 12.5).
      PaymentPurpose.reEntry => s.buyIn,
      PaymentPurpose.addOn => s.effectiveAddOnCost,
    };
  }

  /// Records a simulated payment.
  ///
  /// [idempotencyKey] is what makes a double-tap safe: two attempts carrying
  /// the same key are the same payment, however many times the button was
  /// pressed or a dropped request was retried. Without it, the prize pool
  /// double-counts, which is the failure QA cases PN-DPAY-007 and PN-NEG-011
  /// are looking for.
  ///
  /// [outcome] lets the caller simulate a failure or cancellation, which is
  /// what the dummy checkout sheet offers so the unhappy paths can be tested
  /// at all. Only [PaymentStatus.paid] reaches the prize pool.
  ///
  /// Returns the record — existing one included, when the key was a replay.
  PaymentRecord? recordPayment({
    required String playerId,
    required PaymentPurpose purpose,
    required String idempotencyKey,
    PaymentStatus outcome = PaymentStatus.paid,
    String? failureReason,
  }) {
    final game = _currentGame;
    if (game == null || idempotencyKey.isEmpty) return null;

    // Replay: same key, same payment. Return what is already on file rather
    // than writing a second row.
    final existing = game.payments
        .where((p) => p.idempotencyKey == idempotencyKey)
        .firstOrNull;
    if (existing != null) return existing;

    // A player cannot buy in twice, or take a second add-on. Rebuys are
    // excluded deliberately — a player may rebuy repeatedly, and the limit on
    // that is `rebuyLimit`, enforced where the rebuy is granted.
    final singular =
        purpose == PaymentPurpose.buyIn || purpose == PaymentPurpose.addOn;
    if (singular &&
        outcome == PaymentStatus.paid &&
        game.hasPaid(playerId, purpose)) {
      lastRsvpError =
          '${purpose.label} is already paid for this player.';
      if (!_disposed) notifyListeners();
      return null;
    }

    final record = PaymentRecord(
      id: 'pay-${DateTime.now().microsecondsSinceEpoch}',
      playerId: playerId,
      purpose: purpose,
      amount: amountFor(purpose),
      status: outcome,
      timestamp: DateTime.now(),
      idempotencyKey: idempotencyKey,
      failureReason: failureReason,
    );

    _pushUndo();
    _currentGame = game.copyWith(payments: [...game.payments, record]);

    final player =
        game.players.where((p) => p.id == playerId).firstOrNull;
    addAuditRecord(
      'payment_${outcome.name}',
      '${purpose.label} ${outcome.label.toLowerCase()} for '
          '${player?.name ?? playerId} — ${record.amount}.',
    );

    // Only a successful payment changes the money. A failed or cancelled
    // attempt is recorded and otherwise inert, which is what QA cases
    // PN-DPAY-011, PN-DPAY-012 and PN-NEG-012 check.
    if (outcome.countsTowardPool) _updatePrizePool();

    _syncGroupGame();
    if (!_disposed) notifyListeners();
    return record;
  }

  /// Every payment on file for a player, newest first.
  List<PaymentRecord> paymentsFor(String playerId) {
    final game = _currentGame;
    if (game == null) return const [];
    return game.payments.where((p) => p.playerId == playerId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Whether this player still owes their entry.
  bool owesBuyIn(String playerId) {
    final game = _currentGame;
    if (game == null) return false;
    return !game.hasPaid(playerId, PaymentPurpose.buyIn);
  }

  /// Players who have checked in but not settled their entry — the list a host
  /// actually wants before starting.
  List<Player> get unpaidPlayers {
    final game = _currentGame;
    if (game == null) return const [];
    return game.players
        .where((p) => p.checkedIn && p.confirmed && owesBuyIn(p.id))
        .toList();
  }
}
