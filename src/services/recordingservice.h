// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QPair>
#include <QRect>
#include <QString>
#include <QList>

struct RecordingSettings
{
    enum class OutputType { Gif, Video };
    enum class Codec { H264, HEVC };

    OutputType outputType = OutputType::Video;
    Codec codec = Codec::H264;
    int frameRate = 30;
    int longEdge = 0;
    int customWidth = 0;
    int customHeight = 0;
    int bitRateMbps = 0;
    QString microphoneDeviceId;
    int gifLoopCount = 0;
    int maxDurationSeconds = 30;
    bool captureSystemAudio = true;
    bool captureMicrophone = false;
    bool showCursor = true;
    bool highlightClicks = false;
};

class RecordingService : public QObject
{
    Q_OBJECT
public:
    explicit RecordingService(QObject* parent = nullptr);
    ~RecordingService() override;

    static bool isAvailable();
    static bool systemAudioAvailable();
    static bool requestMicrophonePermission();
    static QList<QPair<QString, QString>> audioInputDevices();

    bool start(const QRect& globalRegion,
               const QString& outputPath,
               const RecordingSettings& settings);
    void pause();
    void resume();
    void stop();
    void cancel();
    bool isRecording() const;
    bool isPaused() const;

signals:
    void started();
    void pausedChanged(bool paused);
    void elapsedChanged(qint64 milliseconds);
    void finished(const QString& path);
    void failed(const QString& message);

private:
    void* m_native = nullptr;
};
