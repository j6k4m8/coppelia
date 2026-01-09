import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

extension CornerRadiusScale on BuildContext {
  double get cornerRadiusScale =>
      Provider.of<AppState>(this, listen: false).cornerRadiusScale;

  double scaledRadius(double value) => value * cornerRadiusScale;
}
