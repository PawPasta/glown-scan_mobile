import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/product_api.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({required this.productId, this.api, super.key});
  final String productId;
  final ProductApi? api;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final ProductApi _api = widget.api ?? ProductApi();
  late final Future<ProductDetail> _product = _api.get(widget.productId);
  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _openExternalUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !{'https', 'http'}.contains(uri.scheme)) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the product website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product details')),
    body: FutureBuilder<ProductDetail>(
      future: _product,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (item.imageUrls.isNotEmpty)
              Image.network(
                item.imageUrls.first,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            if (item.brand != null) Text(item.brand!),
            const SizedBox(height: 14),
            if (item.description != null) Text(item.description!),
            if (item.ingredients.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Ingredients',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(item.ingredients.join(', ')),
            ],
            if (item.usageInstructions != null) ...[
              const SizedBox(height: 18),
              Text(
                'How to use',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(item.usageInstructions!),
            ],
            if (item.warnings.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Warnings', style: Theme.of(context).textTheme.titleMedium),
              Text(item.warnings.join('\n')),
            ],
            if (item.affiliateDisclosure != null) ...[
              const SizedBox(height: 18),
              Text(
                item.affiliateDisclosure!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (item.externalUrl != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openExternalUrl(item.externalUrl!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Visit retailer'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
