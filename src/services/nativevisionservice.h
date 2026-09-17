// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QImage>
#include <QString>
#include <QStringList>

class NativeVisionService
{
public:
    static bool isAvailable();
    static QString recognizeText(const QImage& image, QString* error = nullptr);
    static QStringList recognizeQRCodes(const QImage& image,
                                        QString* error = nullptr);
};
