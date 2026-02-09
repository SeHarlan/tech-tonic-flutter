/// All shader parameters that can be randomized from a seed.
///
/// This mirrors the JS `randomizeShaderParameters()` function
/// and all the global variables it sets.
class ParameterState {
  // Blocking
  bool fxWithBlocking;
  double blockingScale;

  // Movement
  double shouldMoveThreshold;
  bool useMoveBlob;
  double moveShapeSpeed;
  List<double> moveShapeScale;
  double moveSpeed;

  // Fall
  double shouldFallThreshold;
  bool useFallBlob;
  double fallShapeSpeed;
  List<double> shouldFallScale;
  double fallWaterfallMult;

  // Black noise
  double blackNoiseThreshold;
  List<double> blackNoiseScale;
  double blackNoiseEdgeMult;

  // Reset
  double resetThreshold;
  List<double> resetNoiseScale;
  double resetEdgeThreshold;

  // Ribbon/dirt
  List<double> dirtNoiseScale;
  double ribbonDirtThreshold;
  double useRibbonThreshold;

  // Blank static
  List<double> blankStaticScale;
  double blankStaticThreshold;
  double blankStaticTimeMult;

  // Extra fall
  double extraFallShapeThreshold;
  List<double> extraFallShapeScale;
  double extraFallStutterThreshold;
  List<double> extraFallStutterScale;
  double extraFallShapeTimeMult;

  // Extra move
  double extraMoveShapeThreshold;
  List<double> extraMoveShapeScale;
  double extraMoveStutterThreshold;
  List<double> extraMoveStutterScale;

  // Timing
  double baseChunkSize;
  double blockTimeMult;
  double structuralTimeMult;
  double targetFps;

  // Colors
  List<double> blankColor;
  List<double> staticColor1;
  List<double> staticColor2;
  List<double> staticColor3;
  double cycleColorHueSpeed;
  bool useGrayscale;

  // Global flags
  bool globalFreeze;
  bool manualMode;
  bool forceReset;

  ParameterState({
    this.fxWithBlocking = false,
    this.blockingScale = 128.0,
    this.shouldMoveThreshold = 0.2,
    this.useMoveBlob = false,
    this.moveShapeSpeed = 0.025,
    this.moveShapeScale = const [0.5, 5.0],
    this.moveSpeed = 0.0033,
    this.shouldFallThreshold = 0.2,
    this.useFallBlob = false,
    this.fallShapeSpeed = 0.044,
    this.shouldFallScale = const [10.0, 0.5],
    this.fallWaterfallMult = 2.0,
    this.blackNoiseThreshold = 0.5,
    this.blackNoiseScale = const [0.0625, 0.0625],
    this.blackNoiseEdgeMult = 0.025,
    this.resetThreshold = 0.5,
    this.resetNoiseScale = const [0.0625, 0.0625],
    this.resetEdgeThreshold = 0.33,
    this.dirtNoiseScale = const [2500.1, 2490.9],
    this.ribbonDirtThreshold = 0.9,
    this.useRibbonThreshold = 0.25,
    this.blankStaticScale = const [100.0, 0.01],
    this.blankStaticThreshold = 0.33,
    this.blankStaticTimeMult = 2.0,
    this.extraFallShapeThreshold = 0.2,
    this.extraFallShapeScale = const [30.0, 1.0],
    this.extraFallStutterThreshold = 0.1,
    this.extraFallStutterScale = const [50.0, 500.01],
    this.extraFallShapeTimeMult = 0.025,
    this.extraMoveShapeThreshold = 0.2,
    this.extraMoveShapeScale = const [1.0, 10.0],
    this.extraMoveStutterThreshold = 0.1,
    this.extraMoveStutterScale = const [500.0, 50.01],
    this.baseChunkSize = 160.0,
    this.blockTimeMult = 0.05,
    this.structuralTimeMult = 0.01,
    this.targetFps = 60.0,
    this.blankColor = const [0.0, 0.0, 0.0],
    this.staticColor1 = const [1.0, 0.0, 0.0],
    this.staticColor2 = const [0.0, 1.0, 0.0],
    this.staticColor3 = const [0.0, 0.0, 1.0],
    this.cycleColorHueSpeed = 0.0025,
    this.useGrayscale = false,
    this.globalFreeze = false,
    this.manualMode = false,
    this.forceReset = false,
  });

  /// Convert to the flat `Map<String, double>` expected by GenerativePainter.
  Map<String, double> toShaderParams() {
    return {
      'targetFps': targetFps,
      'baseChunkSize': baseChunkSize,
      'shouldMoveThreshold': manualMode ? 0.0 : shouldMoveThreshold,
      'moveSpeed': moveSpeed,
      'moveShapeScaleX': moveShapeScale[0],
      'moveShapeScaleY': moveShapeScale[1],
      'moveShapeSpeed': moveShapeSpeed,
      'resetThreshold': resetThreshold,
      'resetEdgeThreshold': resetEdgeThreshold,
      'resetNoiseScaleX': resetNoiseScale[0],
      'resetNoiseScaleY': resetNoiseScale[1],
      'shouldFallThreshold': manualMode ? 0.0 : shouldFallThreshold,
      'shouldFallScaleX': shouldFallScale[0],
      'shouldFallScaleY': shouldFallScale[1],
      'fallShapeSpeed': fallShapeSpeed,
      'fxWithBlocking': fxWithBlocking ? 1.0 : 0.0,
      'blockTimeMult': blockTimeMult,
      'structuralTimeMult': structuralTimeMult,
      'extraMoveShapeThreshold': manualMode ? 0.0 : extraMoveShapeThreshold,
      'extraMoveStutterScaleX': extraMoveStutterScale[0],
      'extraMoveStutterScaleY': extraMoveStutterScale[1],
      'extraMoveStutterThreshold': extraMoveStutterThreshold,
      'extraFallShapeThreshold': manualMode ? 0.0 : extraFallShapeThreshold,
      'extraFallStutterScaleX': extraFallStutterScale[0],
      'extraFallStutterScaleY': extraFallStutterScale[1],
      'extraFallStutterThreshold': extraFallStutterThreshold,
      'fallWaterfallMult': fallWaterfallMult,
      'extraFallShapeScaleX': extraFallShapeScale[0],
      'extraFallShapeScaleY': extraFallShapeScale[1],
      'extraFallShapeTimeMult': extraFallShapeTimeMult,
      'blockingScale': blockingScale,
      'blackNoiseScaleX': blackNoiseScale[0],
      'blackNoiseScaleY': blackNoiseScale[1],
      'blackNoiseEdgeMult': blackNoiseEdgeMult,
      'blackNoiseThreshold': blackNoiseThreshold,
      'useRibbonThreshold': useRibbonThreshold,
      'dirtNoiseScaleX': dirtNoiseScale[0],
      'dirtNoiseScaleY': dirtNoiseScale[1],
      'ribbonDirtThreshold': ribbonDirtThreshold,
      'blankStaticScaleX': blankStaticScale[0],
      'blankStaticScaleY': blankStaticScale[1],
      'blankStaticThreshold': blankStaticThreshold,
      'blankStaticTimeMult': blankStaticTimeMult,
      'blankColorR': blankColor[0],
      'blankColorG': blankColor[1],
      'blankColorB': blankColor[2],
      'useGrayscale': useGrayscale ? 1.0 : 0.0,
      'staticColor1R': staticColor1[0],
      'staticColor1G': staticColor1[1],
      'staticColor1B': staticColor1[2],
      'staticColor2R': staticColor2[0],
      'staticColor2G': staticColor2[1],
      'staticColor2B': staticColor2[2],
      'staticColor3R': staticColor3[0],
      'staticColor3G': staticColor3[1],
      'staticColor3B': staticColor3[2],
      'extraMoveShapeScaleX': extraMoveShapeScale[0],
      'extraMoveShapeScaleY': extraMoveShapeScale[1],
      'cycleColorHueSpeed': cycleColorHueSpeed,
      'manualMode': manualMode ? 1.0 : 0.0,
      'forceReset': forceReset ? 1.0 : 0.0,
    };
  }
}
