import 'package:flutter_test/flutter_test.dart';
import 'package:icon_extreme/core/errors.dart';
import 'package:icon_extreme/core/forms/form_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('slugify makes safe web addresses', () {
    expect(slugify('Kampala Road Works!'), 'kampala-road-works');
    expect(slugify('  --Hello  World-- '), 'hello-world');
    expect(slugify('???'), 'item');
  });

  test('database errors become plain sentences', () {
    expect(friendlyError(const PostgrestException(message: 'dup', code: '23505')), contains('already used'));
    expect(friendlyError(const PostgrestException(message: 'new row violates row-level security policy', code: '42501')),
        contains('not allowed'));
    expect(friendlyError(const PostgrestException(message: 'violates check constraint "testimonials_check"', code: '23514')),
        contains('permission'));
    expect(friendlyError(Exception('offline')), contains('internet'));
  });
}
