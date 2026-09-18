// SPDX-License-Identifier: GPL-3.0-or-later
#include "captureregionservice.h"

bool CaptureRegionService::accessibilityTrusted(bool)
{
    return false;
}

QVector<CaptureRegionCandidate> CaptureRegionService::candidatesAt(const QPoint&)
{
    return {};
}
