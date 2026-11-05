# CoreMiner Sim

![CI](https://github.com/rolympio/CoreMiner-Sim/actions/workflows/ci.yml/badge.svg)

Simulador de circuitos de processamento mineral em Flutter/Dart. A Etapa 5 contempla modelos de moinho de bolas (PBM), hidrociclone com parametrização de Plitt, reciclo por Wegstein, indicadores granulométricos, P80, carga circulante e painel demonstrativo.

## Desenvolvimento

```bash
flutter pub get
flutter test --coverage
```

## Estado da validação

**Não validado com dados industriais reais.** A alimentação de exemplo é demonstrativa. Reconciliação WLS/EKF e calibração com campanhas reais ainda não foram integradas. O circuito fechado ainda não está integrado ao editor gráfico. Nenhum resultado de CI deve ser interpretado como validação física do processo.

## Licença

MIT.
