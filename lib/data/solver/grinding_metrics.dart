import 'dart:math' as math;
import '../../domain/models/mineral_stream.dart';
import '../../domain/models/equipments/grinding_circuit.dart';

class GrindingMetrics {
  static double solidsWeightPercent(MineralStream s) =>
    s.slurryTph==0 ? 0 : 100*s.solidsTph/s.slurryTph;

  /// P80 por interpolação logarítmica dos limites de peneira.
  /// Os valores da SizeGrid são tratados como ABERTURAS (não centros).
  /// Retorna null se 80% passante estiver fora dos limites medidos.
  static double? p80(MineralStream s,SizeGrid grid){
    if(s.retainedFractions.length!=grid.microns.length) throw ArgumentError('Malhas incompatíveis');
    final passing=s.cumulativePassing;
    for(var i=0;i<passing.length-1;i++){
      if(passing[i]>=0.8 && passing[i+1]<=0.8){
        final p1=passing[i],p2=passing[i+1];
        if(p1==p2) return grid.microns[i];
        final t=(0.8-p2)/(p1-p2);
        final a=grid.microns[i],b=grid.microns[i+1];
        // P80 estimado por interpolação log(d) entre aberturas adjacentes.
        return b*math.pow(a/b,t);
      }
    }
    return null;
  }
  static double circulatingLoadPercent(MineralStream recycle,MineralStream fresh){
    if(fresh.solidsTph<=0) throw ArgumentError('Alimentação nova deve ser positiva');
    return 100*recycle.solidsTph/fresh.solidsTph;
  }
}
