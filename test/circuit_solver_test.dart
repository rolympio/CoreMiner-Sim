import 'package:flutter_test/flutter_test.dart';
import 'package:coreminer_sim/data/solver/circuit_solver.dart';
import 'package:coreminer_sim/data/solver/steady_state_solver.dart';
import 'package:coreminer_sim/domain/models/equipments/basic_equipment.dart';
import 'package:coreminer_sim/domain/models/mineral_stream.dart';
import 'package:coreminer_sim/domain/models/process_model.dart';

void main() {
  test('Wegstein converge reciclo linear e confirma residuo real', () {
    final result = const SteadyStateSolver().solve(
      [0], (x) => [100 + 0.8 * x[0]], tolerance: 1e-9);
    expect(result.values.single, closeTo(500, 1e-7));
    expect(result.residual, lessThan(1e-9));
  });

  test('Circuito com misturador e divisor fecha agua, solidos e classes', () {
    final model = ProcessModel(equipments: [
      IdealMixer('mixer'), IdealSplitter('splitter', 0.8),
    ], connections: const [
      ProcessConnection('forward', 'mixer', 'out', 'splitter', 'in'),
      ProcessConnection('return', 'splitter', 'recycle', 'mixer', 'recycle'),
    ]);
    final feed = MineralStream(solidsTph: 100, waterTph: 40,
      solidsDensityGcm3: 3.5, retainedFractions: [0.2, 0.3, 0.5]);
    final result = const CircuitSolver().solve(model, {
      'mixer': {'fresh': feed},
    }, tolerance: 1e-8);
    expect(result.tearConnectionIds, contains('return'));
    expect(result.connections['forward']!.solidsTph, closeTo(500, 1e-6));
    expect(result.connections['return']!.waterTph, closeTo(160, 1e-6));
    expect(result.globalBalance.solidsTph.abs(), lessThan(1e-5));
    expect(result.globalBalance.waterTph.abs(), lessThan(1e-5));
    expect(result.globalBalance.maxAbsoluteError, lessThan(1e-5));
    for (final residual in result.equipmentBalances.values) {
      expect(residual.maxAbsoluteError, lessThan(1e-5));
    }
  });

  test('Reciclo 0.99 converge sem produzir vazoes negativas', () {
    final result = const SteadyStateSolver().solve(
      [0, 0], (x) => [10 + 0.99 * x[0], 3 + 0.99 * x[1]],
      tolerance: 1e-8);
    expect(result.values[0], closeTo(1000, 1e-5));
    expect(result.values[1], closeTo(300, 1e-5));
  });
}
