import 'package:flutter/foundation.dart';

/// A set wrapper with value equality for Riverpod `select` snapshots.
@immutable
class StableSetSelection<T> {
  const StableSetSelection(this.values);

  final Set<T> values;

  bool contains(T value) => values.contains(value);

  @override
  bool operator ==(Object other) =>
      other is StableSetSelection<T> && setEquals(values, other.values);

  @override
  int get hashCode => Object.hashAllUnordered(values);
}
