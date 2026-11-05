import 'dart:math' as math;
import '../equipment.dart';
import '../mineral_stream.dart';

/// Classes ordenadas da mais grossa à mais fina. O último intervalo é o fundo.
/// Diâmetros representativos em micrômetros; precisam ser estritamente decrescentes.
class SizeGrid {
  final List<double> microns;
  SizeGrid(List<double> sizes) : microns = List.unmodifiable(sizes) {
    if (sizes.length < 2 || sizes.any((d) => !d.isFinite || d <= 0)) {
      throw ArgumentError('Malha granulométrica inválida');
    }
    for (var i = 1; i < sizes.length; i++) {
      if (sizes[i] >= sizes[i - 1]) throw ArgumentError('Classes devem ser decrescentes');
    }
  }
}

MineralStream _fromClasses(MineralStream reference, List<double> masses, double water) {
  if (masses.any((m) => !m.isFinite || m < -1e-9) || !water.isFinite || water < 0) {
    throw StateError('Vazões negativas ou não finitas');
  }
  final clean = masses.map((m) => math.max(0.0, m)).toList();
  final total = clean.fold(0.0, (double a, double b) => a + b);
  return MineralStream(
    solidsTph: total, waterTph: water,
    solidsDensityGcm3: reference.solidsDensityGcm3,
    retainedFractions: total == 0 ? reference.retainedFractions : clean.map((m) => m / total).toList(),
    liberationMatrix: reference.liberationMatrix,
  );
}

/// Moinho de bolas: aproximação PBM em regime permanente por compartimento
/// perfeitamente misturado. Não é um modelo calibrado de potência Bond/Morrell.
/// Para classe j, seleção S_j (1/h), residência tau (h), quebra b_ij.
/// A saída resolve (I + tau*S - tau*B*S)*out = in por substituição progressiva.
class BallMillPbm implements Equipment {
  @override final String id;
  final SizeGrid grid;
  final List<double> selectionPerHour;
  final List<List<double>> daughterFractions;
  final double residenceHours;
  BallMillPbm(this.id, {required this.grid, required List<double> selectionPerHour,
    required List<List<double>> daughterFractions, required this.residenceHours})
      : selectionPerHour = List.unmodifiable(selectionPerHour),
        daughterFractions = List.unmodifiable(daughterFractions.map((r) => List<double>.unmodifiable(r))) {
    final n = grid.microns.length;
    if (!residenceHours.isFinite || residenceHours <= 0 || selectionPerHour.length != n ||
        selectionPerHour.any((s) => !s.isFinite || s < 0) || daughterFractions.length != n ||
        daughterFractions.any((r) => r.length != n)) throw ArgumentError('PBM: dimensões/parâmetros inválidos');
    if (selectionPerHour.last != 0) throw ArgumentError('Classe de fundo não deve sofrer quebra');
    for (var j = 0; j < n; j++) {
      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        final b = daughterFractions[i][j];
        if (!b.isFinite || b < 0 || (i <= j && b != 0)) throw ArgumentError('Matriz de quebra inválida');
        sum += b;
      }
      if (j < n - 1 && (sum - 1).abs() > 1e-10) throw ArgumentError('Quebra da classe $j não conserva massa');
    }
  }
  @override String get name => 'Moinho de bolas PBM';
  @override List<EquipmentPort> get ports => const [EquipmentPort('in', PortDirection.input), EquipmentPort('out', PortDirection.output)];
  @override Map<String, double> get parameters => {'residenceHours': residenceHours};
  @override String get algorithmInsights => '0 = feed_i - out_i - tau*S_i*out_i + tau*sum(j<i,b_ij*S_j*out_j). Água conservada; quebra conservativa.';
  @override Map<String, MineralStream> calculate(Map<String, MineralStream> inputs) {
    final feed = inputs['in'];
    if (feed == null || feed.retainedFractions.length != grid.microns.length) throw StateError('Moinho: alimentação/malha inválida');
    final incoming = feed.solidsBySizeTph;
    final out = List<double>.filled(incoming.length, 0);
    for (var i = 0; i < out.length; i++) {
      var generated = 0.0;
      for (var j = 0; j < i; j++) {
        generated += residenceHours * daughterFractions[i][j] * selectionPerHour[j] * out[j];
      }
      out[i] = (incoming[i] + generated) / (1 + residenceHours * selectionPerHour[i]);
    }
    return {'out': _fromClasses(feed, out, feed.waterTph)};
  }
}

/// Hidrociclone com curva de partição corrigida tipo Plitt (forma reduzida).
/// d50c deve ser estimado/calibrado externamente; NÃO implementa a correlação
/// geométrica empírica completa de Plitt ou Nageswararao.
/// A recuperação corrigida de sólidos para overflow é
/// P_o(d)=exp(-ln(2)*(d/d50c)^m); underflow=1-P_o.
/// Bypass de água para underflow, beta, arrasta a mesma fração de cada classe.
class PlittPartitionCyclone implements Equipment {
  @override final String id;
  final SizeGrid grid;
  final double d50cMicrons, sharpness, waterToUnderflow;
  PlittPartitionCyclone(this.id, {required this.grid, required this.d50cMicrons,
    required this.sharpness, required this.waterToUnderflow}) {
    if (!d50cMicrons.isFinite || d50cMicrons <= 0 || !sharpness.isFinite || sharpness <= 0 ||
        !waterToUnderflow.isFinite || waterToUnderflow < 0 || waterToUnderflow >= 1) {
      throw ArgumentError('Parâmetros de ciclone inválidos');
    }
  }
  @override String get name => 'Hidrociclone — partição tipo Plitt';
  @override List<EquipmentPort> get ports => const [EquipmentPort('in', PortDirection.input),
    EquipmentPort('overflow', PortDirection.output), EquipmentPort('underflow', PortDirection.output)];
  @override Map<String, double> get parameters => {'d50cMicrons': d50cMicrons, 'sharpness': sharpness, 'waterToUnderflow': waterToUnderflow};
  @override String get algorithmInsights => 'P_overflow_corrigida=exp(-ln(2)*(d/d50c)^m); P_underflow=beta+(1-beta)*(1-P_overflow_corrigida).';
  @override Map<String, MineralStream> calculate(Map<String, MineralStream> inputs) {
    final feed = inputs['in'];
    if (feed == null || feed.retainedFractions.length != grid.microns.length) throw StateError('Ciclone: alimentação/malha inválida');
    final masses = feed.solidsBySizeTph;
    final under = List<double>.generate(masses.length, (i) {
      final overCorrected = math.exp(-math.ln2 * math.pow(grid.microns[i] / d50cMicrons, sharpness));
      final fraction = waterToUnderflow + (1 - waterToUnderflow) * (1 - overCorrected);
      return masses[i] * fraction;
    });
    final over = List<double>.generate(masses.length, (i) => masses[i] - under[i]);
    return {
      'overflow': _fromClasses(feed, over, feed.waterTph * (1 - waterToUnderflow)),
      'underflow': _fromClasses(feed, under, feed.waterTph * waterToUnderflow),
    };
  }
}
