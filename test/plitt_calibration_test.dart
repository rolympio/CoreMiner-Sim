import 'package:flutter_test/flutter_test.dart';
import 'package:coreminer_sim/domain/models/mineral_stream.dart';
import 'package:coreminer_sim/domain/models/equipments/grinding_circuit.dart';
import 'package:coreminer_sim/domain/models/equipments/plitt_calibrated.dart';
import 'package:coreminer_sim/data/solver/grinding_metrics.dart';
import 'package:coreminer_sim/data/solver/grinding_calibration.dart';

void main(){
 final grid=SizeGrid([1000,500,250,125,63,20]);
 final feed=MineralStream(solidsTph:100,waterTph:40,solidsDensityGcm3:3.5,
   retainedFractions:[.20,.25,.20,.15,.12,.08]);
 const g=PlittGeometry(cycloneCm:25,inletCm:6,vortexCm:8,apexCm:5,
   freeVortexCm:60,pressureKpa:100);
 test('Plitt: fechamento de massa por classe e água',(){
   final cyclone=CalibratedPlittCyclone('c',grid:grid,geometry:g);
   final result=cyclone.calculate({'in':feed});
   final uf=result['underflow']!,of=result['overflow']!;
   expect(uf.solidsTph+of.solidsTph,closeTo(feed.solidsTph,1e-8));
   expect(uf.waterTph+of.waterTph,closeTo(feed.waterTph,1e-8));
   for(var i=0;i<grid.microns.length;i++){
     expect(uf.solidsBySizeTph[i]+of.solidsBySizeTph[i],closeTo(feed.solidsBySizeTph[i],1e-8));
   }
   expect(cyclone.performance(feed).d50cMicrons,greaterThan(0));
 });
 test('Indicadores de sólidos e carga circulante',(){
   expect(GrindingMetrics.solidsWeightPercent(feed),closeTo(71.4285714286,1e-8));
   expect(GrindingMetrics.circulatingLoadPercent(feed,feed),100);
 });
 test('Ajuste de parâmetros recupera observação sintética',(){
   const trueGeometry=PlittGeometry(cycloneCm:25,inletCm:6,vortexCm:8,
     apexCm:5,freeVortexCm:60,pressureKpa:100,d50Factor:1.3,
     splitFactor:0.8,sharpnessFactor:1.2);
   final trueModel=CalibratedPlittCyclone('true',grid:grid,geometry:trueGeometry);
   final uf=trueModel.calculate({'in':feed})['underflow']!;
   final fit=CycloneCalibration.fit(grid,g,[CycloneObservation(feed,
     uf.retainedFractions,uf.waterTph/feed.waterTph)]);
   final predicted=CalibratedPlittCyclone('fit',grid:grid,geometry:fit)
     .calculate({'in':feed})['underflow']!;
   for(var i=0;i<grid.microns.length;i++){
     expect(predicted.retainedFractions[i],closeTo(uf.retainedFractions[i],2e-3));
   }
 });
}
