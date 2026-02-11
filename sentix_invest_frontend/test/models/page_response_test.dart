import 'package:flutter_test/flutter_test.dart';
import 'package:sentix_invest_frontend/core/models/page_response.dart';

// Simple model for testing
class _TestItem {
  final String name;
  final int value;

  _TestItem({required this.name, required this.value});

  factory _TestItem.fromJson(Map<String, dynamic> json) {
    return _TestItem(name: json['name'] ?? '', value: json['value'] ?? 0);
  }
}

void main() {
  group('PageResponse', () {
    test('fromJson parses full response correctly', () {
      final json = {
        'content': [
          {'name': 'Item A', 'value': 1},
          {'name': 'Item B', 'value': 2},
        ],
        'page': 0,
        'size': 10,
        'totalElements': 25,
        'totalPages': 3,
        'last': false,
      };

      final result = PageResponse.fromJson(json, _TestItem.fromJson);

      expect(result.content.length, 2);
      expect(result.content[0].name, 'Item A');
      expect(result.content[1].value, 2);
      expect(result.page, 0);
      expect(result.size, 10);
      expect(result.totalElements, 25);
      expect(result.totalPages, 3);
      expect(result.last, false);
    });

    test('hasMore returns true when not last page', () {
      final json = {
        'content': [
          {'name': 'Item', 'value': 1},
        ],
        'page': 0,
        'size': 1,
        'totalElements': 5,
        'totalPages': 5,
        'last': false,
      };

      final result = PageResponse.fromJson(json, _TestItem.fromJson);
      expect(result.hasMore, true);
    });

    test('hasMore returns false on last page', () {
      final json = {
        'content': [
          {'name': 'Item', 'value': 1},
        ],
        'page': 4,
        'size': 1,
        'totalElements': 5,
        'totalPages': 5,
        'last': true,
      };

      final result = PageResponse.fromJson(json, _TestItem.fromJson);
      expect(result.hasMore, false);
    });

    test('isEmpty returns true for empty content', () {
      final json = {
        'content': [],
        'page': 0,
        'size': 10,
        'totalElements': 0,
        'totalPages': 0,
        'last': true,
      };

      final result = PageResponse.fromJson(json, _TestItem.fromJson);
      expect(result.isEmpty, true);
    });

    test('isEmpty returns false when content exists', () {
      final json = {
        'content': [
          {'name': 'Item', 'value': 1},
        ],
        'page': 0,
        'size': 10,
        'totalElements': 1,
        'totalPages': 1,
        'last': true,
      };

      final result = PageResponse.fromJson(json, _TestItem.fromJson);
      expect(result.isEmpty, false);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{
        'content': null,
      };

      final result = PageResponse.fromJson(json, _TestItem.fromJson);

      expect(result.content, isEmpty);
      expect(result.page, 0);
      expect(result.size, 20);
      expect(result.totalElements, 0);
      expect(result.totalPages, 0);
      expect(result.last, true);
    });

    test('fromJson handles completely empty map', () {
      final result =
          PageResponse.fromJson(<String, dynamic>{}, _TestItem.fromJson);

      expect(result.content, isEmpty);
      expect(result.page, 0);
      expect(result.last, true);
      expect(result.isEmpty, true);
      expect(result.hasMore, false);
    });
  });
}
