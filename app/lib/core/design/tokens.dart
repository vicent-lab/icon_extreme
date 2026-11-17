import 'package:material_ui/material_ui.dart';

/// Every spacing, corner and status colour the app uses lives here, so the whole look
/// can be tuned from one file.
class Space {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

class Radii {
  static const double card = 12, control = 10, pill = 20;
}

/// One meaning per colour, used the same way on every screen:
/// green = finished, amber = in progress, red = problem, grey-blue = not started.
class Tone {
  static final done = Colors.green.shade700;
  static final active = Colors.orange.shade800;
  static final problem = Colors.red.shade700;
  static const idle = Colors.blueGrey;
}

Color statusColor(String s) => switch (s) {
      'ongoing' || 'in_progress' => Tone.active,
      'completed' || 'done' => Tone.done,
      'on_hold' || 'delayed' => Tone.problem,
      _ => Tone.idle,
    };
