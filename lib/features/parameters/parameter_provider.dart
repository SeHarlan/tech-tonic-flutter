import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'parameter_state.dart';
import 'seed_generator.dart';

/// Provides the current [ParameterState], regenerated when the seed changes.
class ParameterNotifier extends Notifier<ParameterState> {
  @override
  ParameterState build() {
    final seed = ref.watch(seedProvider);
    return generateFromSeed(seed);
  }

  /// Update a single parameter at runtime (e.g. from a slider).
  void update(void Function(ParameterState p) mutator) {
    mutator(state);
    ref.notifyListeners();
  }

  void toggleManualMode() {
    state.manualMode = !state.manualMode;
    ref.notifyListeners();
  }

  void toggleGlobalFreeze() {
    state.globalFreeze = !state.globalFreeze;
    ref.notifyListeners();
  }

  void setForceReset(bool value) {
    state.forceReset = value;
    ref.notifyListeners();
  }
}

/// The integer seed that drives parameter randomization.
final seedProvider = StateProvider<int>((ref) {
  return DateTime.now().millisecondsSinceEpoch % 10000;
});

/// Provides [ParameterState] that regenerates when [seedProvider] changes.
final parameterProvider =
    NotifierProvider<ParameterNotifier, ParameterState>(ParameterNotifier.new);
