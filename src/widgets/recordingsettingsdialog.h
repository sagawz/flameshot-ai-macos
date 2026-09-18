// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include "src/services/recordingservice.h"

class QWidget;

class RecordingSettingsDialog
{
public:
    static bool getSettings(RecordingSettings::OutputType type,
                            RecordingSettings* settings,
                            QWidget* parent);
};
