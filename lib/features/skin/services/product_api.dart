import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.ingredients = const [],
    this.usageInstructions,
    this.warnings = const [],
    this.imageUrls = const [],
    this.externalUrl,
    this.affiliateDisclosure,
  });
  final String id, name;
  final String? brand,
      description,
      usageInstructions,
      externalUrl,
      affiliateDisclosure;
  final List<String> ingredients, warnings, imageUrls;
  factory ProductDetail.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String) {
      throw const ApiException(
        'The product response is invalid.',
        kind: ApiErrorKind.invalidResponse,
      );
    }
    List<String> list(String key) =>
        (value[key] as List? ?? const []).whereType<String>().toList();
    return ProductDetail(
      id: value['id'] as String,
      name: value['name'] as String,
      brand: value['brand'] as String?,
      description: value['description'] as String?,
      ingredients: list('ingredients'),
      usageInstructions: value['usageInstructions'] as String?,
      warnings: list('warnings'),
      imageUrls: list('imageUrls'),
      externalUrl: value['externalUrl'] as String?,
      affiliateDisclosure: value['affiliateDisclosure'] as String?,
    );
  }
}

class ProductApi {
  ProductApi({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();
  final ApiClient _client;
  Future<ProductDetail> get(String id) async => ProductDetail.fromJson(
    (await _client.get(
      '${ApiEndpoints.products}/$id',
      requiresAuth: true,
    )).data,
  );
  void close() => _client.close();
}
