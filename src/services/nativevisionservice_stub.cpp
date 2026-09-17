// SPDX-License-Identifier: GPL-3.0-or-later
#include "nativevisionservice.h"

bool NativeVisionService::isAvailable()
{
    return false;
}

QString NativeVisionService::recognizeText(const QImage&, QString* error)
{
    if (error) {
        *error = QStringLiteral("Local OCR is currently available on macOS only.");
    }
    return {};
}

QStringList NativeVisionService::recognizeQRCodes(const QImage&, QString* error)
{
    if (error) {
        *error = QStringLiteral("Local QR recognition is currently available on macOS only.");
    }
    return {};
}
