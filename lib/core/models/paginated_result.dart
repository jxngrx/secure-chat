class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final String? nextCursor;

  const PaginatedResult({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  factory PaginatedResult.empty() {
    return const PaginatedResult(
      items: [],
      hasMore: false,
      nextCursor: null,
    );
  }
}
