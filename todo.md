# TODO

-   [ ] put the time (progress/length) on the same line as the seek bar in the mini player when it's on the bottom of the page
-   [ ] reduce size of multibutton text in settings

## Integrations

-   [ ] add AirPlay device picker + playback route integration (iOS/macOS)
-   [ ] add Chromecast support + cast-friendly stream URLs (Android)
-   [ ] CarPlay/Android Auto support? Is that a separate thing?

## Backlog

-   [ ] [BUG] Favorites → Artists view sometimes empty
-   [ ] Crossfade controls (requires dual-player mixing probably?)

## BUGS

if i click playlist > ... > rename > cancel, i get

```

══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following assertion was thrown building RawGestureDetector(state:
RawGestureDetectorState#db283(gestures: [tap, long press, tap and pan], excludeFromSemantics: true,
behavior: translucent)):
A TextEditingController was used after being disposed.
Once you have called dispose() on a TextEditingController, it can no longer be used.

The relevant error-causing widget was:
  TextField
  TextField:file:///Users/jordan/Documents/projects/github/j6k4m8/copellia/lib/ui/widgets/playlist_dialogs.dart:37:18

When the exception was thrown, this was the stack:
#0      ChangeNotifier.debugAssertNotDisposed.<anonymous closure> (package:flutter/src/foundation/change_notifier.dart:182:9)
#1      ChangeNotifier.debugAssertNotDisposed (package:flutter/src/foundation/change_notifier.dart:189:6)
#2      ChangeNotifier.addListener (package:flutter/src/foundation/change_notifier.dart:271:27)
#3      _MergingListenable.addListener (package:flutter/src/foundation/change_notifier.dart:503:14)
#4      _AnimatedState.didUpdateWidget (package:flutter/src/widgets/transitions.dart:119:25)
#5      StatefulElement.update (package:flutter/src/widgets/framework.dart:5994:55)
#6      Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#7      SingleChildRenderObjectElement.update (package:flutter/src/widgets/framework.dart:7125:14)
#8      Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#9      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#10     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#11     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#12     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#13     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#14     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#15     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#16     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#17     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#18     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#19     SingleChildRenderObjectElement.update (package:flutter/src/widgets/framework.dart:7125:14)
#20     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#21     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#22     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#23     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#24     StatefulElement.update (package:flutter/src/widgets/framework.dart:6010:5)
#25     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#26     SingleChildRenderObjectElement.update (package:flutter/src/widgets/framework.dart:7125:14)
#27     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#28     SingleChildRenderObjectElement.update (package:flutter/src/widgets/framework.dart:7125:14)
#29     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#30     SingleChildRenderObjectElement.update (package:flutter/src/widgets/framework.dart:7125:14)
#31     Element.updateChild (package:flutter/src/widgets/framework.dart:4037:15)
#32     ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:5844:16)
#33     StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:5985:11)
#34     Element.rebuild (package:flutter/src/widgets/framework.dart:5532:7)
#35     BuildScope._tryRebuild (package:flutter/src/widgets/framework.dart:2750:15)
#36     BuildScope._flushDirtyElements (package:flutter/src/widgets/framework.dart:2807:11)
#37     BuildOwner.buildScope (package:flutter/src/widgets/framework.dart:3111:18)
#38     WidgetsBinding.drawFrame (package:flutter/src/widgets/binding.dart:1262:21)
#39     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:495:5)
#40     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1434:15)
#41     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1347:9)
#42     SchedulerBinding._handleDrawFrame (package:flutter/src/scheduler/binding.dart:1200:5)
#43     _invoke (dart:ui/hooks.dart:356:13)
#44     PlatformDispatcher._drawFrame (dart:ui/platform_dispatcher.dart:444:5)
#45     _drawFrame (dart:ui/hooks.dart:328:31)

════════════════════════════════════════════════════════════════════════════════════════════════════

Another exception was thrown: 'package:flutter/src/widgets/framework.dart': Failed assertion: line 6271 pos 12: '_dependents.isEmpty': is not true.

```
