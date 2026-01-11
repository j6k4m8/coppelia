import 'package:flutter/widgets.dart';
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

extension CornerRadiusScale on BuildContext {
  double get cornerRadiusScale =>
      Provider.of<AppState>(this).cornerRadiusScale;

  double scaledRadius(double value) => value * cornerRadiusScale;
}
