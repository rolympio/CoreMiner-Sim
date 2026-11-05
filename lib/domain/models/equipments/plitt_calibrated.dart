import 'dart:math' as math;
import '../equipment.dart';
import '../mineral_stream.dart';
import 'grinding_circuit.dart';

/// Plitt (1976), variante SI documentada em Encyclopedia of Separation Science.
/// Geometria em cm, Q em L/min, pressão em kPa, densidades em g/cm³.
/// Coeficientes empíricos variam entre publicações: identificar a variante
/// e ajustar fatores antes de utilizar previsões em operação.
class PlittGeometry {
  final double cycloneCm, inletCm, vortexCm, apexCm, freeVortexCm;
  final double pressureKpa, liquidDensity, d50Factor, splitFactor, sharpnessFactor;
  const PlittGeometry({required this.cycloneCm, required this.inletCm,
    required this.vortexCm, required this.apexCm, required this.freeVortexCm,
    required this.pressureKpa, this.liquidDensity = 1,
    this.d50Factor = 1, this.splitFactor = 1, this.sharpnessFactor = 1});
  void validate() {
    final values = [cycloneCm,inletCm,vortexCm,apexCm,freeVortexCm,
      pressureKpa,liquidDensity,d50Factor,splitFactor,sharpnessFactor];
    if (values.any((x) => !x.isFinite || x <= 0) ||
        inletCm >= cycloneCm || vortexCm >= cycloneCm || apexCm >= cycloneCm) {
      throw ArgumentError('Geometria, pressão ou fatores Plitt inválidos');
    }
  }
}

class PlittPerformance {
  final double d50cMicrons, sharpness, waterUnderflowFraction;
  final double feedLpm, solidsVolumePercent, pulpDensity;
  const PlittPerformance(this.d50cMicrons,this.sharpness,
    this.waterUnderflowFraction,this.feedLpm,this.solidsVolumePercent,this.pulpDensity);
}

class CalibratedPlittCyclone implements Equipment {
  @override final String id;
  final SizeGrid grid;
  final PlittGeometry geometry;
  CalibratedPlittCyclone(this.id,{required this.grid,required this.geometry}) {
    geometry.validate();
  }
  @override String get name => 'Hidrociclone Plitt calibrável';
  @override List<EquipmentPort> get ports => const [
    EquipmentPort('in',PortDirection.input),
    EquipmentPort('overflow',PortDirection.output),
    EquipmentPort('underflow',PortDirection.output)];
  @override Map<String,double> get parameters => {
    'Dc_cm':geometry.cycloneCm,'Di_cm':geometry.inletCm,
    'Do_cm':geometry.vortexCm,'Du_cm':geometry.apexCm,
    'h_cm':geometry.freeVortexCm,'pressure_kPa':geometry.pressureKpa,
    'F_d50':geometry.d50Factor,'F_split':geometry.splitFactor,
    'F_sharpness':geometry.sharpnessFactor};
  @override String get algorithmInsights =>
    'Plitt: d50c=F1*50.5*Dc^0.46*Di^0.60*Do^1.21*exp(0.063*Cv)/(Du^0.71*h^0.38*Q^0.45*sqrt(rhoS-rhoL)); '
    'S=F2*3.28*(Du/Do)^3.31*h^0.54*(Du²+Do²)^0.36*rhoP^0.24*exp(0.0054*Cv)/(P^0.24*Dc^1.11); '
    'm=F3*1.94*exp(-1.58*Rv)*(Dc²*h/Q)^0.15; Rv=S/(1+S). '
    'Bypass de água aproximado por Rv; variante empírica requer calibração.';

  PlittPerformance performance(MineralStream feed) {
    final g=geometry;
    final solidVolume=feed.solidsTph/feed.solidsDensityGcm3;
    final liquidVolume=feed.waterTph/g.liquidDensity;
    final totalVolume=solidVolume+liquidVolume;
    if (totalVolume <= 0 || feed.solidsDensityGcm3 <= g.liquidDensity) {
      throw ArgumentError('Alimentação vazia ou contraste de densidade inválido');
    }
    // t/h / (t/m³) = m³/h; conversão m³/h -> L/min = 1000/60.
    final q=totalVolume*1000/60;
    final cv=100*solidVolume/totalVolume;
    final rhoP=feed.slurryTph/totalVolume;
    final d50=g.d50Factor*50.5*math.pow(g.cycloneCm,0.46)*
      math.pow(g.inletCm,0.60)*math.pow(g.vortexCm,1.21)*math.exp(0.063*cv)/
      (math.pow(g.apexCm,0.71)*math.pow(g.freeVortexCm,0.38)*
       math.pow(q,0.45)*math.sqrt(feed.solidsDensityGcm3-g.liquidDensity));
    final split=g.splitFactor*3.28*math.pow(g.apexCm/g.vortexCm,3.31)*
      math.pow(g.freeVortexCm,0.54)*
      math.pow(g.apexCm*g.apexCm+g.vortexCm*g.vortexCm,0.36)*
      math.pow(rhoP,0.24)*math.exp(0.0054*cv)/
      (math.pow(g.pressureKpa,0.24)*math.pow(g.cycloneCm,1.11));
    final rv=split/(1+split);
    final m=g.sharpnessFactor*1.94*math.exp(-1.58*rv)*
      math.pow(g.cycloneCm*g.cycloneCm*g.freeVortexCm/q,0.15);
    if (![d50,rv,m].every((x)=>x.isFinite && x>0) || rv>=1) {
      throw StateError('Predição Plitt fora do domínio numérico');
    }
    return PlittPerformance(d50.toDouble(),m.toDouble(),rv.toDouble(),q,cv,rhoP);
  }

  @override Map<String,MineralStream> calculate(Map<String,MineralStream> inputs) {
    final feed=inputs['in'];
    if(feed==null || feed.retainedFractions.length!=grid.microns.length) {
      throw ArgumentError('Corrente ou malha incompatível');
    }
    final p=performance(feed);
    final under=List<double>.generate(grid.microns.length,(i){
      final corrected=1-math.exp(-math.ln2*
        math.pow(grid.microns[i]/p.d50cMicrons,p.sharpness));
      return feed.solidsBySizeTph[i]*(p.waterUnderflowFraction+
        (1-p.waterUnderflowFraction)*corrected);
    });
    final over=List<double>.generate(under.length,(i)=>feed.solidsBySizeTph[i]-under[i]);
    MineralStream stream(List<double> masses,double water){
      final solids=masses.fold<double>(0,(a,b)=>a+b);
      return MineralStream(solidsTph:solids,waterTph:water,
        solidsDensityGcm3:feed.solidsDensityGcm3,
        retainedFractions:solids==0?feed.retainedFractions:
          masses.map((v)=>v/solids).toList());
    }
    return {'underflow':stream(under,feed.waterTph*p.waterUnderflowFraction),
      'overflow':stream(over,feed.waterTph*(1-p.waterUnderflowFraction))};
  }
}
