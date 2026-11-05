import 'equipment.dart';

class ProcessConnection {
  final String id, sourceEquipment, sourcePort, targetEquipment, targetPort;
  const ProcessConnection(this.id, this.sourceEquipment, this.sourcePort,
      this.targetEquipment, this.targetPort);
}

class ProcessModel {
  final List<Equipment> equipments;
  final List<ProcessConnection> connections;
  const ProcessModel({required this.equipments, required this.connections});

  void validate() {
    final ids = equipments.map((e) => e.id).toSet();
    if (ids.length != equipments.length) throw StateError('IDs duplicados');
    for (final edge in connections) {
      if (!ids.contains(edge.sourceEquipment) || !ids.contains(edge.targetEquipment)) {
        throw StateError('Conexão ${edge.id} aponta para equipamento inexistente');
      }
      final source = equipments.firstWhere((e) => e.id == edge.sourceEquipment);
      final target = equipments.firstWhere((e) => e.id == edge.targetEquipment);
      if (!source.ports.any((p) => p.id == edge.sourcePort && p.direction == PortDirection.output) ||
          !target.ports.any((p) => p.id == edge.targetPort && p.direction == PortDirection.input)) {
        throw StateError('Portas incompatíveis: ${edge.id}');
      }
    }
  }
}
