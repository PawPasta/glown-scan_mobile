import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/core/network/api_client.dart';
import 'package:glown_scan_mobile/core/network/api_endpoints.dart';
import 'package:glown_scan_mobile/features/skin/services/product_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads a mobile product detail', () async {
    final api = ProductApi(
      apiClient: ApiClient(
        baseUri: Uri.parse('https://api.glownscan.xyz/'),
        accessTokenProvider: () async => 'token',
        httpClient: MockClient((request) async {
          expect(request.url.path, '${ApiEndpoints.products}/product-1');
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'status': 200,
                'message': 'Success',
                'data': {
                  'id': 'product-1',
                  'name': 'Daily Moisturizer',
                  'ingredients': ['Niacinamide'],
                  'imageUrls': ['https://example.com/image.jpg'],
                },
              }),
            ),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(api.close);

    final product = await api.get('product-1');

    expect(product.ingredients, ['Niacinamide']);
    expect(product.imageUrls, ['https://example.com/image.jpg']);
  });
}
