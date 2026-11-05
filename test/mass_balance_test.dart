import 'package:flutter_test/flutter_test.dart';
import 'package:coreminer_sim/domain/models/mineral_stream.dart';
import 'package:coreminer_sim/data/solver/mass_balance.dart';
import 'package:coreminer_sim/data/solver/steady_state_solver.dart';

void main() {
  test('Balanço conservativo', () {
    final feed = MineralStream(solidsTph: 100, waterTph: 40,
        solidsDensityGcm3: 3.5, retainedFractions: [0.2, 0.3, 0.5]);
    final product = MineralStream(solidsTph: 100, waterTph: 40,
        solidsDensityGcm3: 3.5, retainedFractions: [0.2, 0.3, 0.5]);
    expect(balance([feed], [product]).maxAbsoluteError, lessThan(1e-5));
  });
  test('Reciclo linear converge em isolate', () async {
    final result = await const SteadyStateSolver()
        .solveLinearRecycleAsync([100], 0.5);
    expect((result.values.single - 200).abs(), lessThan(1e-4));
    expect(result.residual, lessThan(1e-5));
  });
}
