// SPDX-License-Identifier: GPL-3.0-or-later
#include "recordingservice.h"

RecordingService::RecordingService(QObject* parent) : QObject(parent) {}
RecordingService::~RecordingService() = default;
bool RecordingService::isAvailable() { return false; }
bool RecordingService::systemAudioAvailable() { return false; }
bool RecordingService::requestMicrophonePermission() { return false; }
QList<QPair<QString, QString>> RecordingService::audioInputDevices() { return {}; }
bool RecordingService::start(const QRect&, const QString&, const RecordingSettings&)
{
    emit failed(tr("Recording is only available on macOS 12.3 or later."));
    return false;
}
void RecordingService::pause() {}
void RecordingService::resume() {}
void RecordingService::stop() {}
void RecordingService::cancel() {}
bool RecordingService::isRecording() const { return false; }
bool RecordingService::isPaused() const { return false; }
