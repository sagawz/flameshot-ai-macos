// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QPoint>
#include <QRect>
#include <QString>
#include <QVector>

struct CaptureRegionCandidate
{
    enum class Type
    {
        Control,
        Dialog,
        Window,
        Screen
    };

    QRect geometry;
    Type type = Type::Window;
    QString applicationName;
    QString role;
    qint64 windowId = 0;
    int priority = 0;
};

class CaptureRegionService
{
public:
    static bool accessibilityTrusted(bool prompt = false);
    static QVector<CaptureRegionCandidate> candidatesAt(const QPoint& globalPos);
};
