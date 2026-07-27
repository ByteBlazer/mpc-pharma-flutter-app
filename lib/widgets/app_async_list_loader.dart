class AppAsyncListLoader<T> {
  int refreshToken = 0;
  late Future<T> future;

  void initialize(Future<T> Function() load) {
    future = load();
  }

  Future<T> reload({
    required Future<T> Function() load,
    required void Function(void Function()) setState,
  }) async {
    final nextToken = refreshToken + 1;
    final nextFuture = load();
    setState(() {
      refreshToken = nextToken;
      future = nextFuture;
    });
    return nextFuture;
  }
}
