import '../models/inventory.dart';

/// Výsledek výpočtu pro Mezinárodní zprávu o brzdění vlaku (MZOB).
class MzobResult {
  final int wagonCount;
  final double weight;
  final double brakeWeight;
  final int lengthMeters;
  final int axleCount;
  final double handbrakeForceKn;
  final int nonMetallicBlocksCount;
  final int gModeCount;
  final int pModeCount;
  final int handbrakeCount;
  final String? note;

  const MzobResult({
    required this.wagonCount,
    required this.weight,
    required this.brakeWeight,
    required this.lengthMeters,
    required this.axleCount,
    required this.handbrakeForceKn,
    required this.nonMetallicBlocksCount,
    required this.gModeCount,
    required this.pModeCount,
    required this.handbrakeCount,
    this.note,
  });
}

/// Součet hmotností vozů – používá se pro předběžné vyhodnocení, zda bude
/// potřeba dotázat se na počet přestavovačů v režimu G (práh 1200 t).
double sumWagonWeight(List<WagonNumber> wagons) {
  var total = 0.0;
  for (final wagon in wagons) {
    total += wagon.weight ?? 0;
  }
  return total;
}

/// Spočítá výsledek pro MZOB podle zadané hmotnosti nákladu.
///
/// [gSwitchCount] (3 nebo 5) je vyžadován pouze pokud součet hmotnosti
/// nákladu a vozů dosáhne 1200 t nebo více a [cargoMass] je vyšší než 0.
MzobResult calculateMzob({
  required List<WagonNumber> wagons,
  required double cargoMass,
  int? gSwitchCount,
}) {
  final wagonCount = wagons.length;
  final totalWagonWeight = sumWagonWeight(wagons);
  final weight = totalWagonWeight + cargoMass;

  double brakeWeight;
  int gModeCount;
  int pModeCount;
  String? note;

  if (cargoMass <= 0) {
    brakeWeight = wagons.fold(0.0, (sum, w) => sum + (w.brakeWeightG ?? 0));
    gModeCount = 0;
    pModeCount = wagonCount;
    note = null;
  } else {
    final gross = totalWagonWeight + cargoMass;
    final totalBrakeWeightP =
        wagons.fold(0.0, (sum, w) => sum + (w.brakeWeightP ?? 0));

    if (gross < 800) {
      brakeWeight = totalBrakeWeightP;
      gModeCount = 0;
      pModeCount = wagonCount;
      note = null;
    } else if (gross < 1200) {
      brakeWeight = totalBrakeWeightP;
      gModeCount = 0;
      pModeCount = wagonCount;
      note = 'Lokomotiva v režimu G';
    } else {
      assert(gSwitchCount == 3 || gSwitchCount == 5);
      final k = (gSwitchCount ?? 0).clamp(0, wagonCount);
      final gWagons = wagons.take(k);
      final pWagons = wagons.skip(k);
      final gSum = gWagons.fold(0.0, (sum, w) => sum + (w.brakeWeightP ?? 0));
      final pSum = pWagons.fold(0.0, (sum, w) => sum + (w.brakeWeightP ?? 0));
      brakeWeight = gSum * 0.75 + pSum;
      gModeCount = k;
      pModeCount = wagonCount - k;
      note = null;
    }
  }

  final lengthMeters =
      wagons.fold(0.0, (sum, w) => sum + (w.length ?? 0)).ceil();
  final axleCount = wagons.fold(0, (sum, w) => sum + (w.axleCount ?? 0));
  final handbrakeForceKn = wagons
      .where((w) => w.handbrake)
      .fold(0.0, (sum, w) => sum + (w.handbrakeForceKn ?? 0));
  final nonMetallicBlocksCount =
      wagons.where((w) => w.nonMetallicBlocks).length;
  final handbrakeCount = wagons.where((w) => w.handbrake).length;

  return MzobResult(
    wagonCount: wagonCount,
    weight: weight,
    brakeWeight: brakeWeight,
    lengthMeters: lengthMeters,
    axleCount: axleCount,
    handbrakeForceKn: handbrakeForceKn,
    nonMetallicBlocksCount: nonMetallicBlocksCount,
    gModeCount: gModeCount,
    pModeCount: pModeCount,
    handbrakeCount: handbrakeCount,
    note: note,
  );
}
