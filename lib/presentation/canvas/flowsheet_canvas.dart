import 'package:flutter/material.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

/// Canvas inicial; os IDs das portas serão ligados ao ProcessModel na etapa 3.
class FlowsheetCanvas extends StatefulWidget {
  const FlowsheetCanvas({super.key});
  @override
  State<FlowsheetCanvas> createState() => _FlowsheetCanvasState();
}

class _FlowsheetCanvasState extends State<FlowsheetCanvas> {
  late final NodeFlowController<String, dynamic> controller =
      NodeFlowController<String, dynamic>(nodes: [
    Node<String>(id: 'feed', type: 'feed', position: const Offset(100, 160),
        data: 'Alimentação', outputPorts: const [
          Port(id: 'out', name: 'Saída', offset: Offset(2, 40)),
        ]),
    Node<String>(id: 'mill', type: 'mill', position: const Offset(420, 160),
        data: 'Moinho de bolas', inputPorts: const [
          Port(id: 'in', name: 'Entrada', offset: Offset(-2, 40)),
        ], outputPorts: const [
          Port(id: 'out', name: 'Saída', offset: Offset(2, 40)),
        ]),
  ], connections: [
    Connection(id: 'feed-mill', sourceNodeId: 'feed', sourcePortId: 'out',
        targetNodeId: 'mill', targetPortId: 'in'),
  ]);

  @override
  Widget build(BuildContext context) => NodeFlowEditor<String, dynamic>(
    controller: controller,
    theme: NodeFlowTheme.dark,
    nodeBuilder: (context, node) => Padding(
      padding: const EdgeInsets.all(16),
      child: Text(node.data, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}
