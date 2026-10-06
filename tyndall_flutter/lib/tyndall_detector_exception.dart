class DetectorException implements Exception {
  const DetectorException(this.message);

  final String message;

  @override
  String toString() => message;
}