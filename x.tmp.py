def edit(p, old, new):
    s = open(p, encoding='utf-8', newline='').read()
    if '\r\n' in s:
        old = old.replace('\n', '\r\n')
        new = new.replace('\n', '\r\n')
    assert old in s, (p, old[:70])
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8', newline='').write(s)


p = 'lib/screens/cash/cash_game_live_screen.dart'

# ---- action type + state -------------------------------------------------
edit(p, "enum _CashActionType { buyIn, cashOut }", "enum _CashActionType { buyIn, topUp, cashOut }")
edit(p, '''  bool _showReconcile = false;
''', '''  bool _showReconcile = false;
  bool _showCashOutAll = false;
''')

# ---- edit modal: stack is typed in chips ---------------------------------
edit(p, '''  void _openEdit(CashPlayer p) {
    setState(() {
      _editPlayerId = p.id;
      _editStack.text = _num(p.stack);''', '''  void _openEdit(CashPlayer p, double chipValue) {
    setState(() {
      _editPlayerId = p.id;
      _editStack.text = _num(p.stack / chipValue);''')
edit(p, '''    app.cashEditPlayer(
      id,
      stack: stack,''', '''    app.cashEditPlayer(
      id,
      stack: stack * (app.cashSession?.settings.chipValue ?? 1),''')

# ---- confirm action: top-up, toast with undo -----------------------------
edit(p, '''    if (action.type == _CashActionType.buyIn && amt <= 0) return;

    String? error;
    if (action.type == _CashActionType.buyIn) {
      final pid = action.playerId;
      if (pid != null) {
        error = app.cashBuyIn(pid, amt);
      } else if (_newPlayerName.text.trim().isNotEmpty) {
        error = app.cashBuyIn(_newPlayerName.text.trim(), amt, isNew: true);
        if (error == null) _newPlayerName.clear();
      }
    } else if (action.type == _CashActionType.cashOut &&
        action.playerId != null) {
      // Returns a message when the cash-out is refused (a 17th open balance);
      // the snackbar below then explains it instead of silently doing nothing.
      error = app.cashCashOut(action.playerId!, amt);
    }
''', '''    final who = app.cashSession?.players
        .where((p) => p.id == action.playerId)
        .firstOrNull
        ?.name;
    String? message;
    String? error;
    if (action.type == _CashActionType.buyIn) {
      final pid = action.playerId;
      if (pid != null) {
        error = app.cashBuyIn(pid, amt);
        message = '$who rejoins with ${_num(amt)}';
      } else if (_newPlayerName.text.trim().isNotEmpty) {
        final name = _newPlayerName.text.trim();
        error = app.cashBuyIn(name, amt, isNew: true);
        if (error == null) _newPlayerName.clear();
        message = '$name sits down with ${_num(amt)}';
      } else {
        error = 'Enter a name for the new player.';
      }
    } else if (action.type == _CashActionType.topUp &&
        action.playerId != null) {
      error = app.cashTopUp(action.playerId!, amt);
      message = '$who tops up ${_num(amt)} - hand over ${_num(amt)} in chips';
    } else if (action.type == _CashActionType.cashOut &&
        action.playerId != null) {
      // Returns a message when the cash-out is refused (a 17th open balance);
      // the snackbar below then explains it instead of silently doing nothing.
      error = app.cashCashOut(action.playerId!, amt);
      message = '$who cashes out ${_num(amt)}';
    }
''')
edit(p, '''    setState(() {
      _action = null;
      _amount.clear();
    });
  }

  void _endGame(AppProvider app) {''', '''    setState(() {
      _action = null;
      _amount.clear();
    });
    if (message != null && mounted) {
      // T125: every ledger change can be taken back from its own toast.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Undo', onPressed: app.undoCashAction),
          ),
        );
    }
  }

  /// D2: "End session & settle" is ready once everyone has cashed out; used
  /// earlier it first asks to cash everyone out at their current stack.
  void _requestEnd(AppProvider app) {
    final session = app.cashSession;
    if (session == null) return;
    final seated = session.players.any((p) => !p.isCashedOut);
    setState(() {
      _showReconcile = false;
      if (seated) {
        _showCashOutAll = true;
      } else {
        _showEndModal = true;
      }
    });
  }

  void _endGame(AppProvider app) {''')

# ---- session menu: end goes through the gate -----------------------------
edit(p, '''                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() => _showEndModal = true);
                  },''', '''                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _requestEnd(app);
                  },''')

# ---- player action sheet --------------------------------------------------
edit(p, '''                          Text(
                            'In ${player.totalBuyIns.toInt()} · Stack ${player.stack.toInt()}',
                            style: TextStyle(''', '''                          Text(
                            player.isCashedOut
                                ? 'In ${Formatters.money('', player.totalBuyIns)} · cashed out ${Formatters.money('', player.cashedOut)}'
                                : 'In ${Formatters.money('', player.totalBuyIns)} · Stack ${_num(player.stack / (app.cashSession?.settings.chipValue ?? 1))}'
                                    '${_bbLabel(app.cashSession, player)}',
                            style: TextStyle(''')
edit(p, '''                    title: Text(
                      'Buy-in / Rebuy',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openAction(
                        _CashAction(_CashActionType.buyIn, player.id),
                        preset: app.cashSession?.settings.minBuyIn,
                      );
                    },
                  ),''', '''                    title: Text(
                      'Top-up',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openAction(
                        _CashAction(_CashActionType.topUp, player.id),
                      );
                    },
                  ),''')
edit(p, '''                      _openAction(
                        _CashAction(_CashActionType.cashOut, player.id),
                        preset: player.stack,
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: AppColors.foreground),''', '''                      _openAction(
                        _CashAction(_CashActionType.cashOut, player.id),
                        preset:
                            player.stack /
                            (app.cashSession?.settings.chipValue ?? 1),
                      );
                    },
                  ),
                ] else
                  ListTile(
                    leading: Icon(
                      Icons.login_outlined,
                      color: AppColors.successText,
                    ),
                    title: Text(
                      'Rejoin',
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    subtitle: Text(
                      'Reopens the row for a new buy-in',
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openAction(
                        _CashAction(_CashActionType.buyIn, player.id),
                        preset: app.cashSession?.settings.minBuyIn,
                      );
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: AppColors.foreground),''')
edit(p, '''                    Navigator.of(sheetContext).pop();
                    _openEdit(player);''', '''                    Navigator.of(sheetContext).pop();
                    _openEdit(player, app.cashSession?.settings.chipValue ?? 1);''')

# ---- build: no host gate --------------------------------------------------
edit(p, '''    if (!app.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Host access required.')),
      );
    }

    final session = app.cashSession;''', '''    final session = app.cashSession;''')

edit(p, '''        ? 'Buy in / rebuy'
        : _action?.type == _CashActionType.cashOut''', '''        ? 'Rejoin'
        : _action?.type == _CashActionType.topUp
        ? 'Top-up'
        : _action?.type == _CashActionType.cashOut''')

# ---- reconciliation card ---------------------------------------------------
edit(p, '''                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expected in play',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      Formatters.prize(session.expectedInPlay.toInt()),
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Difference',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      session.difference == 0
                          ? '0'
                          : session.difference > 0
                          ? '+${session.difference.toInt()}'
                          : '${session.difference.toInt()}',
                      style: TextStyle(
                        color: session.difference >= 0
                            ? AppColors.successText
                            : AppColors.destructiveText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],''', '''                _ledgerRow('Chip value issued', session.totalBuyIns),
                const SizedBox(height: 10),
                _ledgerRow('Chip value returned', session.totalCashedOut),
                const SizedBox(height: 10),
                _ledgerRow(
                  'Still on the table',
                  session.expectedInPlay,
                  bold: true,
                ),
                const SizedBox(height: 12),
                Text(
                  "This tracks chip value only - Poker Night doesn't process or "
                  'confirm real payments.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],''')
# tint while anyone is still playing
edit(p, '''            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _ledgerRow('Chip value issued', session.totalBuyIns),''', '''            decoration: BoxDecoration(
              // Red-tinted while anyone is still playing: a running total, not
              // an error (D2).
              color: players.any((p) => !p.isCashedOut)
                  ? AppColors.destructiveSoft
                  : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _ledgerRow('Chip value issued', session.totalBuyIns),''')

# ---- players list + empty state + bottom actions --------------------------
edit(p, '''          // Player Cards List
          for (var i = 0; i < players.length; i++)''', '''          // Player Cards List
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nobody is seated yet. Tap + Add to seat the first player.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          for (var i = 0; i < players.length; i++)''')
edit(p, '''          // Bottom Action Button: Cash out & settle
          InkWell(
            onTap: () => setState(() => _showReconcile = true),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Glass.primaryGlow,
              ),
              child: Text(
                'Cash out & settle',
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
''', '''          // Bottom actions (D2): a preview that writes nothing, then the end.
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            variant: AppButtonVariant.secondary,
            onPressed: () => setState(() => _showReconcile = true),
            child: const Text('Preview settle-up'),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: players.isEmpty ? null : () => _requestEnd(app),
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: players.isEmpty ? 0.5 : 1,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: Glass.primaryGlow,
                ),
                child: Text(
                  'End session & settle',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
''')
edit(p, '''          if (_showReconcile) _buildReconcileModal(context, app, session),''', '''          if (_showReconcile) _buildReconcileModal(context, app, session),
          if (_showCashOutAll) _buildCashOutAllModal(context, app),''')

# ---- player card: net / cashed out line -----------------------------------
edit(p, '''    final net = player.net;
    final netText = net > 0
        ? '+${net.toInt()}'
        : net < 0
        ? '${net.toInt()}'
        : '0';
''', '''    final net = player.net;
    final netText = net > 0
        ? '+${Formatters.money('', net)}'
        : net < 0
        ? Formatters.money('', net)
        : '0';
''')
edit(p, '''                    'In ${player.totalBuyIns.toInt()} · ${player.buyInCount} buy-in${player.buyInCount == 1 ? '' : 's'}',''', '''                    player.isCashedOut
                        ? 'In ${Formatters.money('', player.totalBuyIns)} · cashed out ${Formatters.money('', player.cashedOut)}'
                        : 'In ${Formatters.money('', player.totalBuyIns)} · ${player.buyInCount} buy-in${player.buyInCount == 1 ? '' : 's'}',''')

# ---- action modal: min/max only for buy-in; chips wording ------------------
edit(p, '''            label: 'Amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),''', '''            label: 'Amount (chips)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),''')

# ---- reconcile modal: respects "Track settlement" --------------------------
edit(p, '''            CashSettlementPanel(
              players: session.players,
              tier: app.premiumTier,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              variant: AppButtonVariant.danger,
              fullWidth: true,
              onPressed: () {
                setState(() {
                  _showReconcile = false;
                  _showEndModal = true;
                });
              },
              child: const Text('End session & settle'),
            ),''', '''            if (session.settings.trackSettlement)
              CashSettlementPanel(
                players: session.players,
                tier: app.premiumTier,
              )
            else
              Text(
                'Settlement tracking is off for this session.',
                style: TextStyle(color: AppColors.foreground),
              ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              variant: AppButtonVariant.danger,
              fullWidth: true,
              onPressed: () => _requestEnd(app),
              child: const Text('End session & settle'),
            ),''')

# ---- end modal wording ------------------------------------------------------
edit(p, '''                  'Difference of ${Formatters.signedMoney(session.settings.currency, diff)}. Table does not reconcile.',''', '''                  'Recount: the stacks add up to ${Formatters.money('', session.totalCashedOut + session.totalInPlay)} but ${Formatters.money('', session.totalBuyIns)} was put in. Fix a stack before settling.',''')

# ---- helpers ----------------------------------------------------------------
edit(p, '''  static String _num(num n) => n % 1 == 0 ? '${n.toInt()}' : '$n';''', '''  static String _num(num n) => n % 1 == 0 ? '${n.toInt()}' : '$n';

  /// " · ≈49 BB" for a seated player's stack (D2).
  static String _bbLabel(CashSession? session, CashPlayer player) {
    if (session == null || player.isCashedOut) return '';
    final chips = player.stack / session.settings.chipValue;
    final bb = session.settings.bigBlind;
    if (bb <= 0) return '';
    return ' · ≈${(chips / bb).round()} BB';
  }

  static Widget _ledgerRow(String label, double value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          Formatters.money('', value),
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 16,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCashOutAllModal(BuildContext context, AppProvider app) {
    return AppModal(
      open: true,
      title: 'Cash everyone out?',
      onClose: () => setState(() => _showCashOutAll = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cash out everyone still seated at their current stack?',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            onPressed: () {
              final error = app.cashOutAllSeated();
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AppColors.destructive,
                  ),
                );
                return;
              }
              setState(() {
                _showCashOutAll = false;
                _showEndModal = true;
              });
            },
            child: const Text('Cash out everyone'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.ghost,
            onPressed: () => setState(() => _showCashOutAll = false),
            child: const Text('Not yet'),
          ),
        ],
      ),
    );
  }''')
print('ok')
