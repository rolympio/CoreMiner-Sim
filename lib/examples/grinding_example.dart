import '../domain/models/mineral_stream.dart';
import '../domain/models/process_model.dart';
import '../domain/models/equipments/basic_equipment.dart';
import '../domain/models/equipments/grinding_circuit.dart';
import '../data/solver/circuit_solver.dart';

/// Exemplo didático parametrizado; valores NÃO calibrados com dados de planta.
class GrindingExample {
  final ProcessModel model;
  final Map<String, Map<String, MineralStream>> feed;
  final SizeGrid grid;
  GrindingExample(this.model, this.feed, this.grid);
  Future<CircuitResult> run() => const CircuitSolver().solveAsync(model, feed);
}

GrindingExample createGrindingExample() {
  final grid = SizeGrid([1000, 500, 250, 125, 63, 20]);
  final n = grid.microns.length;
  // Distribuição de fragmentos: cada classe transfere 70% para a próxima
  // e 30% diretamente para o fundo; penúltima transfere 100% ao fundo.
  final b = List.generate(n, (_) => List<double>.filled(n, 0));
  for (var j = 0; j < n - 1; j++) {
    if (j == n - 2) { b[n - 1][j] = 1; }
    else { b[j + 1][j] = 0.7; b[n - 1][j] = 0.3; }
  }
  final mill = BallMillPbm('mill', grid: grid,
      selectionPerHour: [2.0, 1.7, 1.3, 1.0, 0.7, 0],
      daughterFractions: b, residenceHours: 0.45);
  final cyclone = PlittPartitionCyclone('cyclone', grid: grid,
      d50cMicrons: 125, sharpness: 2.0, waterToUnderflow: 0.2);
  final model = ProcessModel(equipments: [IdealMixer('mixer'), mill, cyclone], connections: [
    const ProcessConnection('mixed', 'mixer', 'out', 'mill', 'in'),
    const ProcessConnection('mill_product', 'mill', 'out', 'cyclone', 'in'),
    const ProcessConnection('underflow', 'cyclone', 'underflow', 'mixer', 'recycle'),
  ]);
  final feed = MineralStream(solidsTph: 100, waterTph: 40,
      solidsDensityGcm3: 3.5, retainedFractions: [0.20, 0.25, 0.20, 0.15, 0.12, 0.08]);
  return GrindingExample(model, {'mixer': {'fresh': feed}}, grid);
}
