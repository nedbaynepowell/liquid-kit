// liquid_glass_physics.dart
const double kCollapseScrollThreshold = 4.0;
const double kBlurSigma = 20.0;
const double kOuterPillHeight = 70.0;
const double kInnerPillHeight = 59.0;
const double kOuterPillRadius = 41.0;
const double kInnerPillMargin = 5.5;
const double kTabHorizontalPadding = 4.0;
const double kMaxStretchX = 1.08;
const double kMinSquashY = 0.96;
const double kStretchVelocityFactor = 0.18;
const double kMaxVelocityStretch = 0.85;
const double kTabSwitchStiffness = 300.0;
const double kTabSwitchDamping = 20.0;
const double kTabSwitchMass = 1.0;
const double kLongPressCancelDistance = 6.0;
const double kOuterBarDimOnLift = 0.82;

const Duration kLongPressThreshold = Duration(milliseconds: 400);
const Duration kLiftActivationDuration = Duration(milliseconds: 250);
const Duration kCollapseDuration = Duration(milliseconds: 300);
const Duration kIridescentRotationDuration = Duration(seconds: 3);
