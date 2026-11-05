import '../equipment.dart';
import '../mineral_stream.dart';

/// Misturador ideal: conservação de água e massa de sólidos por classe.
class IdealMixer implements Equipment {
  @override final String id;
  final List<String> inputPorts;
  IdealMixer(this.id, {this.inputPorts = const ['fresh', 'recycle']});
  @override String get name => 'Misturador ideal';
  @override List<EquipmentPort> get ports => [
    for (final p in inputPorts) EquipmentPort(p, PortDirection.input),
    const EquipmentPort('out', PortDirection.output),
  ];
  @override Map<String, double> get parameters => const {};
  @override String get algorithmInsights => 'm_out,i = soma(m_in,i); agua_out = soma(agua_in)';
  @override Map<String, MineralStream> calculate(Map<String, MineralStream> inputs) {
    if (inputs.isEmpty) throw StateError('Misturador sem alimentação');
    final all = inputs.values.toList();
    final n = all.first.retainedFractions.length;
    final density = all.first.solidsDensityGcm3;
    if (all.any((s) => s.retainedFractions.length != n ||
        (s.solidsDensityGcm3 - density).abs() > 1e-8)) {
      throw StateError('Bases incompatíveis no misturador');
    }
    final masses = List<double>.generate(n, (i) =>
        all.fold(0.0, (a, s) => a + s.solidsBySizeTph[i]));
    final solids = masses.fold(0.0, (a, b) => a + b);
    final water = all.fold(0.0, (a, s) => a + s.waterTph);
    return {'out': MineralStream(solidsTph: solids, waterTph: water,
      solidsDensityGcm3: density,
      retainedFractions: solids == 0 ? all.first.retainedFractions :
          masses.map((m) => m / solids).toList())};
  }
}

/// Divisor ideal: split igual para água e todas as classes de sólidos.
class IdealSplitter implements Equipment {
  @override final String id;
  final double recycleFraction;
  IdealSplitter(this.id, this.recycleFraction) {
    if (!recycleFraction.isFinite || recycleFraction < 0 || recycleFraction >= 1) {
      throw ArgumentError('Fração de reciclo deve pertencer a [0,1)');
    }
  }
  @override String get name => 'Divisor ideal';
  @override List<EquipmentPort> get ports => const [
    EquipmentPort('in', PortDirection.input),
    EquipmentPort('recycle', PortDirection.output),
    EquipmentPort('product', PortDirection.output),
  ];
  @override Map<String, double> get parameters => {'recycleFraction': recycleFraction};
  @override String get algorithmInsights => 'm_reciclo = r*m_entrada; m_produto = (1-r)*m_entrada';
  @override Map<String, MineralStream> calculate(Map<String, MineralStream> inputs) {
    final input = inputs['in'];
    if (input == null) throw StateError('Divisor sem alimentação');
    MineralStream scaled(double factor) => MineralStream(
      solidsTph: input.solidsTph * factor,
      waterTph: input.waterTph * factor,
      solidsDensityGcm3: input.solidsDensityGcm3,
      retainedFractions: input.retainedFractions,
      liberationMatrix: input.liberationMatrix,
    );
    return {'recycle': scaled(recycleFraction),
            'product': scaled(1 - recycleFraction)};
  }
}
