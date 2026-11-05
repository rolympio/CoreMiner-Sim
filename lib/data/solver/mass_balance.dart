import '../../domain/models/mineral_stream.dart';

class BalanceResidual {
  final double solidsTph, waterTph;
  final List<double> solidsBySizeTph;
  const BalanceResidual(this.solidsTph, this.waterTph, this.solidsBySizeTph);

  double get maxAbsoluteError {
    final values = [solidsTph.abs(), waterTph.abs(),
      ...solidsBySizeTph.map((v) => v.abs())];
    return values.reduce((a, b) => a > b ? a : b);
  }
}

/// Calcula entrada menos saída, inclusive em cada faixa granulométrica.
/// Em equipamentos que transformam tamanho, somente o balanço global de
/// sólidos deve fechar: classes individuais podem ter resíduos físicos.
BalanceResidual balance(List<MineralStream> inputs, List<MineralStream> outputs) {
  final all = [...inputs, ...outputs];
  if (all.isEmpty) throw ArgumentError('Balanço sem correntes');
  final n = all.first.retainedFractions.length;
  if (all.any((s) => s.retainedFractions.length != n)) {
    throw ArgumentError('Malhas granulométricas incompatíveis');
  }
  double delta(double Function(MineralStream) f) =>
      inputs.fold(0.0, (a, s) => a + f(s)) -
      outputs.fold(0.0, (a, s) => a + f(s));
  return BalanceResidual(delta((s) => s.solidsTph), delta((s) => s.waterTph),
      List.generate(n, (i) => delta((s) => s.solidsBySizeTph[i])));
}
