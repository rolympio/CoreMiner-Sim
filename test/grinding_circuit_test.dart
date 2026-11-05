import 'package:flutter_test/flutter_test.dart';
import 'package:coreminer_sim/examples/grinding_example.dart';
import 'package:coreminer_sim/domain/models/mineral_stream.dart';
import 'package:coreminer_sim/domain/models/equipments/grinding_circuit.dart';

void main() {
  test('PBM conserva sólidos e água, mas redistribui granulometria', () {
    final example = createGrindingExample();
    final mill = example.model.equipments[1] as BallMillPbm;
    final feed = example.feed['mixer']!['fresh']!;
    final product = mill.calculate({'in': feed})['out']!;
    expect((product.solidsTph - feed.solidsTph).abs(), lessThan(1e-8));
    expect(product.waterTph, feed.waterTph);
    expect(product.retainedFractions.first, lessThan(feed.retainedFractions.first));
  });
  test('ciclone conserva cada classe granulométrica e água', () {
    final example = createGrindingExample();
    final cyclone = example.model.equipments[2] as PlittPartitionCyclone;
    final feed = example.feed['mixer']!['fresh']!;
    final result = cyclone.calculate({'in': feed});
    final over = result['overflow']!, under = result['underflow']!;
    for (var i = 0; i < feed.retainedFractions.length; i++) {
      expect((feed.solidsBySizeTph[i] - over.solidsBySizeTph[i] - under.solidsBySizeTph[i]).abs(), lessThan(1e-8));
    }
    expect((feed.waterTph - over.waterTph - under.waterTph).abs(), lessThan(1e-8));
  });
  test('circuito com underflow recirculante converge em isolate', () async {
    final example = createGrindingExample();
    final result = await example.run();
    expect(result.convergence.residual, lessThan(1e-7));
    expect(result.tearConnectionIds, contains('underflow'));
    expect(result.globalBalance.solidsTph.abs(), lessThan(1e-5));
    expect(result.globalBalance.waterTph.abs(), lessThan(1e-5));
    final overflow = result.connections['mill_product']!;
    expect(overflow, isA<MineralStream>());
    expect(result.connections['underflow']!.solidsTph, greaterThan(0));
    // Classes granulométricas não fecham no moinho: a quebra as transforma.
    expect(result.equipmentBalances['mill']!.solidsTph.abs(), lessThan(1e-5));
  });
}
