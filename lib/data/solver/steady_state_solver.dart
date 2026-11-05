import 'dart:isolate';
import 'dart:math' as math;

/// Resultado do ponto fixo: residual é ||F(x)-x|| infinito, não apenas o passo.
class SolverResult {
  final List<double> values;
  final int iterations;
  final double residual;
  final bool converged;
  final List<double> residualHistory;
  const SolverResult(this.values, this.iterations, this.residual,
      {this.converged = true, this.residualHistory = const []});
}

/// Wegstein componente a componente, com fallback amortecido para mapas ruins.
/// F(x) é o valor recalculado do vetor de correntes de reciclo.
class SteadyStateSolver {
  const SteadyStateSolver();

  SolverResult solve(List<double> initial, List<double> Function(List<double>) mapping,
      {double tolerance = 1e-7, int maxIterations = 1000,
      double damping = 0.5, bool useWegstein = true}) {
    if (initial.isEmpty || !tolerance.isFinite || tolerance <= 0 ||
        maxIterations < 1 || !damping.isFinite || damping <= 0 || damping > 1 ||
        initial.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Parâmetros ou estimativas iniciais inválidos');
    }
    var x = List<double>.from(initial);
    List<double>? previousX;
    List<double>? previousF;
    final history = <double>[];
    for (var iteration = 1; iteration <= maxIterations; iteration++) {
      final f = mapping(List<double>.unmodifiable(x));
      if (f.length != x.length || f.any((v) => !v.isFinite || v < 0)) {
        throw StateError('Mapeamento produziu vazão inválida');
      }
      final residual = _norm(f, x);
      history.add(residual);
      if (residual < tolerance) {
        return SolverResult(List.unmodifiable(x), iteration, residual,
            residualHistory: List.unmodifiable(history));
      }
      final next = List<double>.generate(x.length, (j) {
        final basic = x[j] + damping * (f[j] - x[j]);
        if (!useWegstein || previousX == null || previousF == null) return basic;
        final denominator = x[j] - previousX[j];
        if (denominator.abs() < 1e-12) return basic;
        final slope = (f[j] - previousF[j]) / denominator;
        if (!slope.isFinite || slope < -5 || slope > 0.95) return basic;
        // Secante do resíduo g(x)=F(x)-x: x*=(F(x)-s*x)/(1-s).
        final accelerated = (f[j] - slope * x[j]) / (1 - slope);
        if (!accelerated.isFinite || accelerated < 0) return basic;
        // Limite de extrapolação para proteger componentes de fluxo não negativos.
        final cap = math.max(1.0, 10 * math.max(x[j], f[j]));
        return accelerated > cap ? basic : accelerated;
      });
      previousX = x;
      previousF = f;
      x = next;
    }
    final finalF = mapping(List<double>.unmodifiable(x));
    final finalResidual = _norm(finalF, x);
    throw StateError('Wegstein não convergiu: iterações=$maxIterations, '
        'resíduo=$finalResidual (t/h)');
  }

  /// Caso serializável de reciclo linear executado fora da thread da UI.
  Future<SolverResult> solveLinearRecycleAsync(List<double> feed,
      double recycleFraction, {double tolerance = 1e-7}) {
    if (!recycleFraction.isFinite || recycleFraction < 0 || recycleFraction >= 1 ||
        feed.isEmpty || feed.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Alimentação ou fração de reciclo inválida');
    }
    return Isolate.run(() => const SteadyStateSolver().solve(
      List<double>.filled(feed.length, 0),
      (x) => List.generate(feed.length, (i) => feed[i] + recycleFraction * x[i]),
      tolerance: tolerance,
    ));
  }
}

double _norm(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) throw ArgumentError('Dimensões incompatíveis');
  var maximum = 0.0;
  for (var i = 0; i < a.length; i++) {
    maximum = math.max(maximum, (a[i] - b[i]).abs());
  }
  return maximum;
}
