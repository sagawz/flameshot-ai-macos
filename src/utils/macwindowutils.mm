// SPDX-License-Identifier: GPL-3.0-or-later
#include "macwindowutils.h"

#include <QWidget>

#import <AppKit/AppKit.h>

void configureMacCaptureWindow(QWidget* widget)
{
    if (!widget) {
        return;
    }
    NSView* view = (__bridge NSView*)reinterpret_cast<void*>(widget->winId());
    NSWindow* window = view.window;
    if (!window) {
        return;
    }

    // A native fullscreen window becomes its own macOS Space. The capture
    // overlay should instead float over whichever Space is active.
    window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace |
                                NSWindowCollectionBehaviorFullScreenAuxiliary |
                                NSWindowCollectionBehaviorStationary;
    window.level = NSStatusWindowLevel;
    [window setHidesOnDeactivate:NO];
    [window orderFrontRegardless];
}
