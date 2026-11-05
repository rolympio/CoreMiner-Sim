import 'mineral_stream.dart';

enum PortDirection { input, output }

class EquipmentPort {
  final String id;
  final PortDirection direction;
  const EquipmentPort(this.id, this.direction);
}

/// Contrato matemático independente da interface Flutter.
abstract class Equipment {
  String get id;
  String get name;
  List<EquipmentPort> get ports;
  Map<String, double> get parameters;
  String get algorithmInsights;

  /// Recebe correntes por ID da porta e devolve correntes por porta de saída.
  Map<String, MineralStream> calculate(Map<String, MineralStream> inputs);
}
