import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PNQrDisplay extends StatelessWidget {
  final String data;
  final double size;

  const PNQrDisplay({super.key, required this.data, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
    );
  }
}

class PNQrShareCard extends StatelessWidget {
  final String title;
  final String path;
  final String baseUrl;

  const PNQrShareCard({
    super.key,
    required this.title,
    required this.path,
    this.baseUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = baseUrl.isEmpty ? path : '$baseUrl$path';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            PNQrDisplay(data: fullUrl, size: 140),
            const SizedBox(height: 8),
            Text(fullUrl, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
