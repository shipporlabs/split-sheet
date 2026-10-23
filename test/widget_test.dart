// Keeps `flutter create .` from adding its default counter-app test,
// which would not compile against this project.
import 'package:flutter_test/flutter_test.dart';
import 'package:split_sheet/utils/format.dart';

void main() {
  test('greeting returns one of the three options', () {
    expect(['Good morning', 'Good afternoon', 'Good evening'], contains(greeting()));
  });
}
