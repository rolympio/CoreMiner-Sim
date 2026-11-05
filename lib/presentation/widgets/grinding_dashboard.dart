import 'package:flutter/material.dart';
import '../../domain/models/equipments/grinding_circuit.dart';
import '../../domain/models/equipments/plitt_calibrated.dart';
import '../../domain/models/mineral_stream.dart';
import '../../data/solver/grinding_metrics.dart';

/// Painel independente do canvas; gráficos de PSD baseados em CustomPainter.
class GrindingDashboard extends StatefulWidget {
  const GrindingDashboard({super.key});
  @override State<GrindingDashboard> createState()=>_GrindingDashboardState();
}
class _GrindingDashboardState extends State<GrindingDashboard> {
  final grid=SizeGrid([1000,500,250,125,63,20]);
  final fields=<String,TextEditingController>{};
  String? error;
  MineralStream? feed,over,under;
  PlittPerformance? performance;
  @override void initState(){super.initState();
    for(final entry in {'Dc':25.0,'Di':6.0,'Do':8.0,'Du':5.0,'h':60.0,
      'P':100.0,'F1':1.0,'F2':1.0,'F3':1.0}.entries){
      fields[entry.key]=TextEditingController(text:entry.value.toString());
    }
    compute();
  }
  @override void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
  void compute(){try{
    double v(String key)=>double.parse(fields[key]!.text.replaceAll(',','.'));
    final g=PlittGeometry(cycloneCm:v('Dc'),inletCm:v('Di'),vortexCm:v('Do'),
      apexCm:v('Du'),freeVortexCm:v('h'),pressureKpa:v('P'),
      d50Factor:v('F1'),splitFactor:v('F2'),sharpnessFactor:v('F3'));
    final f=MineralStream(solidsTph:100,waterTph:40,solidsDensityGcm3:3.5,
      retainedFractions:[.20,.25,.20,.15,.12,.08]);
    final cyclone=CalibratedPlittCyclone('cyclone',grid:grid,geometry:g);
    final result=cyclone.calculate({'in':f});
    setState((){feed=f;over=result['overflow'];under=result['underflow'];
      performance=cyclone.performance(f);error=null;});
  }catch(e){setState(()=>error=e.toString());}}
  @override Widget build(BuildContext context){
    final controls=ListView(children:[
      const Text('Hidrociclone • parâmetros Plitt',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      for(final key in fields.keys) Padding(padding:const EdgeInsets.only(bottom:8),
        child:TextField(controller:fields[key],keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'$key ${{'Dc':'cm','Di':'cm','Do':'cm','Du':'cm','h':'cm','P':'kPa'}[key]??'(fator)'}',border:const OutlineInputBorder()))),
      FilledButton(onPressed:compute,child:const Text('Calcular')),
      const SizedBox(height:12),
      const Text('Transparência algorítmica',style:TextStyle(fontWeight:FontWeight.bold)),
      const SelectableText('d50c = F1 × 50,5 × Dc^0,46 × Di^0,60 × Do^1,21 × exp(0,063 Cv) / (Du^0,71 × h^0,38 × Q^0,45 × √(ρs−ρl)).\\n'
        'Partição corrigida UF = 1−exp[−ln(2)(d/d50c)^m].\\n'
        'Bypass de água = Rv; fatores F1, F2, F3 devem ser calibrados com dados reais.'),
    ]);
    final results=ListView(children:[
      const Text('Resultados • caso demonstrativo',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      if(error!=null) Text(error!,style:const TextStyle(color:Colors.redAccent)),
      if(performance!=null)...[
        Text('d50c: ${performance!.d50cMicrons.toStringAsFixed(2)} µm'),
        Text('Nitidez m: ${performance!.sharpness.toStringAsFixed(3)}'),
        Text('Recuperação água UF: ${(100*performance!.waterUnderflowFraction).toStringAsFixed(1)}%'),
        Text('Concentração volumétrica: ${performance!.solidsVolumePercent.toStringAsFixed(1)}%'),
        for(final item in [('Feed',feed!),('Overflow',over!),('Underflow',under!)])
          Text('${item.$1}: ${(item.$2 as MineralStream).solidsTph.toStringAsFixed(2)} t/h sólidos | '
            '${GrindingMetrics.solidsWeightPercent(item.$2 as MineralStream).toStringAsFixed(1)}% sólidos | '
            'P80: ${GrindingMetrics.p80(item.$2 as MineralStream,grid)?.toStringAsFixed(1)??'fora da faixa'} µm'),
        const SizedBox(height:18),
        SizedBox(height:230,child:CustomPaint(painter:_PsdPainter([
          feed!.cumulativePassing,over!.cumulativePassing,under!.cumulativePassing]))),
        const Text('Curvas: alimentação (cinza), overflow (ciano), underflow (terracota).'),
        const Text('P80 fora dos limites de peneira não é extrapolado.'),
      ]
    ]);
    return LayoutBuilder(builder:(context,c)=>c.maxWidth>=850?
      Row(children:[SizedBox(width:340,child:controls),const VerticalDivider(),Expanded(child:results)]):
      DefaultTabController(length:2,child:Column(children:[const TabBar(tabs:[Tab(text:'Parâmetros / Insights'),Tab(text:'Resultados')]),
        Expanded(child:TabBarView(children:[controls,results]))])));
  }
}
class _PsdPainter extends CustomPainter {
  final List<List<double>> curves;
  _PsdPainter(this.curves);
  @override void paint(Canvas canvas,Size size){
    final colors=[Colors.grey,Colors.cyan,Colors.deepOrangeAccent];
    final axis=Paint()..color=Colors.grey..strokeWidth=1;
    canvas.drawLine(Offset(25,size.height-20),Offset(size.width-8,size.height-20),axis);
    canvas.drawLine(Offset(25,5),Offset(25,size.height-20),axis);
    for(var k=0;k<curves.length;k++){
      final path=Path();
      for(var i=0;i<curves[k].length;i++){
        final x=25+(size.width-35)*(curves[k].length-1-i)/(curves[k].length-1);
        final y=5+(size.height-25)*(1-curves[k][i]);
        if(i==0)path.moveTo(x,y);else path.lineTo(x,y);
      }
      canvas.drawPath(path,Paint()..color=colors[k]..strokeWidth=2..style=PaintingStyle.stroke);
    }
  }
  @override bool shouldRepaint(covariant _PsdPainter old)=>true;
}
