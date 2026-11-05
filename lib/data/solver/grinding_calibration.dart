import 'dart:math' as math;
import '../../domain/models/mineral_stream.dart';
import '../../domain/models/equipments/grinding_circuit.dart';
import '../../domain/models/equipments/plitt_calibrated.dart';

/// Medições independentes de uma campanha com fechamento de balanço prévio.
/// Cada curva deve representar fração retida em base seca.
class CycloneObservation {
  final MineralStream feed;
  final List<double> underflowRetained;
  final double waterUnderflowFraction;
  const CycloneObservation(this.feed,this.underflowRetained,this.waterUnderflowFraction);
}

class CycloneCalibration {
  /// Ajusta fatores positivos F1 (corte), F2 (split), F3 (nitidez)
  /// por busca coordenada em espaço logarítmico. Não equivale a WLS
  /// com matriz de covariâncias; dados precisam ser reconciliados antes.
  static PlittGeometry fit(SizeGrid grid,PlittGeometry initial,
      List<CycloneObservation> observations,{int sweeps=100}){
    if(observations.isEmpty) throw ArgumentError('Campanha vazia');
    final base=[initial.d50Factor,initial.splitFactor,initial.sharpnessFactor];
    PlittGeometry make(List<double> factors)=>PlittGeometry(
      cycloneCm:initial.cycloneCm,inletCm:initial.inletCm,
      vortexCm:initial.vortexCm,apexCm:initial.apexCm,
      freeVortexCm:initial.freeVortexCm,pressureKpa:initial.pressureKpa,
      liquidDensity:initial.liquidDensity,d50Factor:factors[0],
      splitFactor:factors[1],sharpnessFactor:factors[2]);
    double loss(List<double> factors){
      final model=CalibratedPlittCyclone('fit',grid:grid,geometry:make(factors));
      var total=0.0;
      for(final o in observations){
        if(o.underflowRetained.length!=grid.microns.length) throw ArgumentError('Granulometria observada incompatível');
        final result=model.calculate({'in':o.feed});
        final under=result['underflow']!;
        for(var i=0;i<grid.microns.length;i++){
          final diff=under.retainedFractions[i]-o.underflowRetained[i];
          total+=diff*diff;
        }
        final diff=under.waterTph/o.feed.waterTph-o.waterUnderflowFraction;
        total+=diff*diff;
      }
      return total;
    }
    final factors=List<double>.from(base);
    var step=0.5;
    var best=loss(factors);
    for(var sweep=0;sweep<sweeps;sweep++){
      var improved=false;
      for(var i=0;i<3;i++){
        for(final direction in [-1.0,1.0]){
          final candidate=List<double>.from(factors);
          candidate[i]=(factors[i]*math.exp(direction*step)).clamp(0.05,20.0);
          final value=loss(candidate);
          if(value<best){best=value;factors[i]=candidate[i];improved=true;}
        }
      }
      if(!improved) step*=0.5;
      if(step<1e-6) break;
    }
    return make(factors);
  }
}
