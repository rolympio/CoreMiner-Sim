import 'dart:isolate';
import '../../domain/models/equipment.dart';
import '../../domain/models/mineral_stream.dart';
import '../../domain/models/process_model.dart';
import 'mass_balance.dart';
import 'steady_state_solver.dart';

/// Identifica arestas de corte de reciclo por busca em profundidade.
/// Uma aresta de retorno para um nó na pilha é uma tear stream.
class CircuitResult {
  final SolverResult convergence;
  final Map<String, MineralStream> connections;
  final Map<String, BalanceResidual> equipmentBalances;
  final BalanceResidual globalBalance;
  final List<String> tearConnectionIds;
  const CircuitResult(this.convergence, this.connections,
      this.equipmentBalances, this.globalBalance, this.tearConnectionIds);
}

class CircuitSolver {
  const CircuitSolver();

  /// Executa o circuito inteiro em um isolate, não apenas o caso linear.
  /// Equipamentos precisam ser objetos Dart enviáveis entre isolates.
  Future<CircuitResult> solveAsync(ProcessModel model,
      Map<String, Map<String, MineralStream>> externalInputs,
      {double tolerance = 1e-7, int maxIterations = 500,
      bool useWegstein = true}) => Isolate.run(() => solve(model, externalInputs,
        tolerance: tolerance, maxIterations: maxIterations,
        useWegstein: useWegstein));

  /// externalInputs: equipamento -> porta de entrada -> corrente externa.
  /// Cada entrada de processo admite no máximo uma conexão e nenhuma entrada
  /// externa simultânea; equipamentos com múltiplas entradas devem ter portas
  /// distintas. A distribuição granulométrica e a densidade dos sólidos
  /// devem compartilhar uma base comum de classes e mineralogia.
  CircuitResult solve(ProcessModel model,
      Map<String, Map<String, MineralStream>> externalInputs,
      {double tolerance = 1e-7, int maxIterations = 500,
      bool useWegstein = true}) {
    model.validate();
    final equipments = {for (final e in model.equipments) e.id: e};
    final edges = model.connections;
    final bySource = <String, List<ProcessConnection>>{};
    final byTarget = <String, List<ProcessConnection>>{};
    for (final edge in edges) {
      bySource.putIfAbsent(edge.sourceEquipment, () => []).add(edge);
      byTarget.putIfAbsent(edge.targetEquipment, () => []).add(edge);
    }
    final usedInputs = <String>{};
    for (final edge in edges) {
      if (!usedInputs.add('${edge.targetEquipment}:${edge.targetPort}')) {
        throw StateError('Duas conexões na mesma porta: ${edge.targetEquipment}:${edge.targetPort}');
      }
    }
    for (final entry in externalInputs.entries) {
      final eq = equipments[entry.key];
      if (eq == null) throw StateError('Equipamento externo inexistente: ${entry.key}');
      for (final port in entry.value.keys) {
        if (!eq.ports.any((p) => p.id == port && p.direction == PortDirection.input)) {
          throw StateError('Porta externa inválida: ${entry.key}:$port');
        }
        if (!usedInputs.add('${entry.key}:$port')) {
          throw StateError('Porta recebe corrente externa e conexão: ${entry.key}:$port');
        }
      }
    }
    final samples = [for (final e in externalInputs.values) ...e.values];
    if (samples.isEmpty) throw StateError('Informe pelo menos uma alimentação externa');
    final template = samples.first;
    final n = template.retainedFractions.length;
    if (samples.any((s) => s.retainedFractions.length != n ||
        (s.solidsDensityGcm3 - template.solidsDensityGcm3).abs() > 1e-8)) {
      throw StateError('Bases de granulometria/densidade incompatíveis');
    }
    final tearIds = <String>{};
    final state = <String, int>{};
    void visit(String id) {
      state[id] = 1;
      for (final edge in bySource[id] ?? <ProcessConnection>[]) {
        if (state[edge.targetEquipment] == 1) {
          tearIds.add(edge.id);
        } else if (state[edge.targetEquipment] == null) {
          visit(edge.targetEquipment);
        }
      }
      state[id] = 2;
    }
    for (final id in equipments.keys) {
      if (state[id] == null) visit(id);
    }
    final tearEdges = edges.where((e) => tearIds.contains(e.id)).toList();
    final order = <String>[];
    final visited = <String>{};
    void orderVisit(String id) {
      if (!visited.add(id)) return;
      for (final edge in byTarget[id] ?? <ProcessConnection>[]) {
        if (!tearIds.contains(edge.id)) orderVisit(edge.sourceEquipment);
      }
      order.add(id);
    }
    for (final id in equipments.keys) { orderVisit(id); }

    MineralStream unpack(List<double> values) {
      final solidClasses = values.sublist(0, n);
      final solids = solidClasses.fold(0.0, (a, b) => a + b);
      final retained = solids > 0
          ? solidClasses.map((v) => v / solids).toList()
          : List<double>.from(template.retainedFractions);
      return MineralStream(solidsTph: solids, waterTph: values[n],
          solidsDensityGcm3: template.solidsDensityGcm3,
          retainedFractions: retained,
          liberationMatrix: template.liberationMatrix);
    }
    List<double> pack(MineralStream stream) => [...stream.solidsBySizeTph, stream.waterTph];
    final width = n + 1;
    Map<String, MineralStream> evaluate(List<double> tearVector) {
      final calculated = <String, MineralStream>{};
      for (var t = 0; t < tearEdges.length; t++) {
        calculated[tearEdges[t].id] = unpack(tearVector.sublist(t * width, (t + 1) * width));
      }
      for (final id in order) {
        final eq = equipments[id]!;
        final inputs = <String, MineralStream>{...?externalInputs[id]};
        for (final edge in byTarget[id] ?? <ProcessConnection>[]) {
          final stream = calculated[edge.id];
          if (stream == null) throw StateError('Conexão ${edge.id} não resolvida');
          inputs[edge.targetPort] = stream;
        }
        final outputs = eq.calculate(Map.unmodifiable(inputs));
        for (final edge in bySource[id] ?? <ProcessConnection>[]) {
          final stream = outputs[edge.sourcePort];
          if (stream == null) throw StateError('${eq.id} não produziu porta ${edge.sourcePort}');
          if (stream.retainedFractions.length != n) {
            throw StateError('Granulometria incompatível em ${edge.id}');
          }
          calculated[edge.id] = stream;
        }
      }
      return calculated;
    }
    final initial = List<double>.filled(tearEdges.length * width, 0);
    // Sem reciclo, uma única passagem em ordem topológica é suficiente.
    final convergence = tearEdges.isEmpty
        ? const SolverResult([], 1, 0)
        : SteadyStateSolver().solve(initial, (x) {
            final values = evaluate(x);
            return [for (final edge in tearEdges) ...pack(values[edge.id]!)];
          }, tolerance: tolerance, maxIterations: maxIterations,
          useWegstein: useWegstein);
    final solved = evaluate(convergence.values);
    final balances = <String, BalanceResidual>{};
    for (final eq in model.equipments) {
      final incoming = [
        ...?externalInputs[eq.id]?.values,
        for (final edge in byTarget[eq.id] ?? <ProcessConnection>[]) solved[edge.id]!,
      ];
      final outgoing = [
        for (final edge in bySource[eq.id] ?? <ProcessConnection>[]) solved[edge.id]!,
      ];
      if (incoming.isNotEmpty && outgoing.isNotEmpty) {
        balances[eq.id] = balance(incoming, outgoing);
      }
    }
    // O balanço global contabiliza apenas alimentações externas e saídas
    // terminais explícitas. As conexões internas cancelam por construção.
    final external = [for (final e in externalInputs.values) ...e.values];
    final terminals = <MineralStream>[];
    for (final eq in model.equipments) {
      final inputs = <String, MineralStream>{...?externalInputs[eq.id]};
      for (final edge in byTarget[eq.id] ?? <ProcessConnection>[]) {
        inputs[edge.targetPort] = solved[edge.id]!;
      }
      final outputs = eq.calculate(inputs);
      final linked = (bySource[eq.id] ?? <ProcessConnection>[]).map((e) => e.sourcePort).toSet();
      for (final port in eq.ports.where((p) => p.direction == PortDirection.output)) {
        if (!linked.contains(port.id) && outputs.containsKey(port.id)) terminals.add(outputs[port.id]!);
      }
    }
    final global = balance(external, terminals);
    if (global.solidsTph.abs() > tolerance || global.waterTph.abs() > tolerance) {
      throw StateError('Balanço global não fecha: sólidos=${global.solidsTph}, '
          'água=${global.waterTph} t/h');
    }
    return CircuitResult(convergence, Map.unmodifiable(solved),
        Map.unmodifiable(balances), global, List.unmodifiable(tearIds));
  }
}
