import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/backgrounds.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter a game code.');
      return;
    }
    final result = context.read<AppProvider>().enterGameCode(code);
    if (result == CodeLookupResult.notFound) {
      setState(
        () => _codeError = 'Game not found. Check the code and try again.',
      );
      return;
    }
    if (result == CodeLookupResult.tv) {
      context.go(RoutePaths.tvMode);
    } else {
      context.go(RoutePaths.guestFlow);
    }
  }

  Future<void> _scanQRCode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScanQRScreen()),
    );
    if (scannedCode != null && mounted) {
      setState(() {
        _codeController.text = scannedCode;
      });
      _submitCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.foreground),
          onPressed: () => context.go(RoutePaths.landing),
        ),
      ),
      body: FeltBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.cardGlow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Join Game',
                      style: AppTypography.display(size: AppFontSizes.xl),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enter code or scan QR to join.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _codeController,
                      maxLength: 8,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: AppTypography.monoLg.copyWith(letterSpacing: 3),
                      onChanged: (_) {
                        if (_codeError != null)
                          setState(() => _codeError = null);
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'CODE',
                        hintStyle: AppTypography.monoLg.copyWith(
                          color: AppColors.onSurfaceHint,
                          letterSpacing: 3,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.ring),
                        ),
                      ),
                    ),
                    if (_codeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          _codeError!,
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.lg,
                      onPressed: _submitCode,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login),
                          SizedBox(width: AppSpacing.sm),
                          Text('Enter Game'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'OR',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.lg,
                      onPressed: _scanQRCode,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner),
                          SizedBox(width: AppSpacing.sm),
                          Text('Scan QR Code'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Game QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_hasScanned) return;
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            _hasScanned = true;
            final code = barcodes.first.rawValue!;

            // Extract code if it's a URL
            String extracted = code;
            if (code.contains('code=')) {
              extracted = code.split('code=').last.split('&').first;
            } else if (code.contains('/game/')) {
              extracted = code.split('/game/').last;
            }

            Navigator.pop(context, extracted);
          }
        },
      ),
    );
  }
}
