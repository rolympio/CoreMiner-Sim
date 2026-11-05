/// Corrente material: todas as vazões em toneladas por hora.
/// A granulometria contém frações MÁSSICAS retidas, do grosso ao fino.
class MineralStream {
  final double solidsTph;
  final double waterTph;
  final double solidsDensityGcm3;
  final List<double> retainedFractions;
  final List<List<double>> liberationMatrix;

  MineralStream({
    required this.solidsTph,
    required this.waterTph,
    required this.solidsDensityGcm3,
    required List<double> retainedFractions,
    List<List<double>> liberationMatrix = const [],
  })  : retainedFractions = List.unmodifiable(retainedFractions),
        liberationMatrix = List.unmodifiable(
          liberationMatrix.map((row) => List<double>.unmodifiable(row)),
        ) {
    if (!solidsTph.isFinite || solidsTph < 0 || !waterTph.isFinite || waterTph < 0) {
      throw ArgumentError('Vazões devem ser finitas e não negativas');
    }
    if (!solidsDensityGcm3.isFinite || solidsDensityGcm3 <= 0) {
      throw ArgumentError('Densidade dos sólidos inválida');
    }
    if (retainedFractions.isEmpty ||
        retainedFractions.any((v) => !v.isFinite || v < 0) ||
        (retainedFractions.reduce((a, b) => a + b) - 1).abs() > 1e-8) {
      throw ArgumentError('Frações retidas devem somar 1');
    }
    if (liberationMatrix.isNotEmpty &&
        (liberationMatrix.length != retainedFractions.length ||
         liberationMatrix.any((row) => row.isEmpty ||
           row.any((v) => !v.isFinite || v < 0) ||
           (row.reduce((a, b) => a + b) - 1).abs() > 1e-8))) {
      throw ArgumentError('Matriz de liberação inválida');
    }
  }

  double get slurryTph => solidsTph + waterTph;

  /// Densidade da polpa com volumes aditivos e densidade da água 1 g/cm³.
  double get slurryDensityGcm3 => slurryTph == 0
      ? 0
      : slurryTph / (solidsTph / solidsDensityGcm3 + waterTph);

  /// Massa de sólidos por classe granulométrica (t/h).
  List<double> get solidsBySizeTph =>
      retainedFractions.map((fraction) => fraction * solidsTph).toList();

  /// Fração passante acumulada, da classe grossa à fina.
  List<double> get cumulativePassing {
    var retained = 0.0;
    return retainedFractions.map((fraction) {
      retained += fraction;
      return (1 - retained).clamp(0.0, 1.0);
    }).toList();
  }
}
