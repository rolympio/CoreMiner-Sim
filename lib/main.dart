import 'package:flutter/material.dart';
import 'presentation/canvas/flowsheet_canvas.dart';
import 'presentation/theme/coreminer_theme.dart';
import 'presentation/widgets/grinding_dashboard.dart';

void main() => runApp(const CoreMinerApp());

class CoreMinerApp extends StatelessWidget {
  const CoreMinerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CoreMiner Sim', theme: CoreMinerTheme.dark,
    home: Scaffold(
      appBar: PreferredSize(preferredSize: Size.fromHeight(56),
        child: AppBar(title: Text('CoreMiner Sim | Flowsheet'))),
      body: DefaultTabController(length: 2, child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Fluxograma'), Tab(text: 'Calibração / PSD')]),
        const Expanded(child: TabBarView(children: [FlowsheetCanvas(), GrindingDashboard()])),
      ])),
    ),
  );
}
