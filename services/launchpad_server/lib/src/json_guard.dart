/// The deepest nesting level in [value], counting the outermost list or map
/// as 1 and a bare scalar as 0.
///
/// Stops early and returns `limit + 1` once the nesting exceeds [limit].
/// The walk keeps its own stack rather than recursing, so a hostile
/// document cannot overflow the call stack here. That matters because
/// `jsonEncode` *is* recursive: anything stored must pass this check first.
int jsonDepth(Object? value, {required int limit}) {
  var deepest = 0;
  final pending = <(Object?, int)>[(value, 1)];
  while (pending.isNotEmpty) {
    final (node, depth) = pending.removeLast();
    final Iterable<Object?> children;
    if (node is Map) {
      children = node.values;
    } else if (node is List) {
      children = node;
    } else {
      continue;
    }
    if (depth > deepest) deepest = depth;
    if (depth > limit) return depth;
    for (final child in children) {
      if (child is Map || child is List) pending.add((child, depth + 1));
    }
  }
  return deepest;
}
