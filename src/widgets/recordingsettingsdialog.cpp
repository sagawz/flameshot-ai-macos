// SPDX-License-Identifier: GPL-3.0-or-later
#include "recordingsettingsdialog.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QSpinBox>
#include <QSettings>
#include <QOperatingSystemVersion>
#include <QVBoxLayout>

bool RecordingSettingsDialog::getSettings(RecordingSettings::OutputType type,
                                          RecordingSettings* settings,
                                          QWidget* parent)
{
    QDialog dialog(parent);
    dialog.setWindowTitle(type == RecordingSettings::OutputType::Gif
                            ? QObject::tr("GIF recording settings")
                            : QObject::tr("Video recording settings"));
    auto* layout = new QVBoxLayout(&dialog);
    auto* form = new QFormLayout();
    layout->addLayout(form);

    auto* fps = new QComboBox(&dialog);
    const QList<int> fpsValues = type == RecordingSettings::OutputType::Gif
      ? QList<int>{ 5, 10, 15, 20 }
      : QList<int>{ 15, 24, 30, 60 };
    for (int value : fpsValues) {
        fps->addItem(QString::number(value), value);
    }
    fps->setCurrentIndex(fpsValues.indexOf(type == RecordingSettings::OutputType::Gif
                                             ? 10
                                             : 30));
    form->addRow(QObject::tr("Frame rate"), fps);

    auto* resolution = new QComboBox(&dialog);
    resolution->addItem(QObject::tr("Original"), 0);
    resolution->addItem(QObject::tr("Long edge 1080"), 1080);
    resolution->addItem(QObject::tr("Long edge 720"), 720);
    resolution->addItem(QObject::tr("50%"), -50);
    resolution->addItem(QObject::tr("Custom"), -1);
    form->addRow(QObject::tr("Resolution"), resolution);

    auto* customWidth = new QSpinBox(&dialog);
    auto* customHeight = new QSpinBox(&dialog);
    customWidth->setRange(2, 7680);
    customHeight->setRange(2, 4320);
    customWidth->setValue(1920);
    customHeight->setValue(1080);
    customWidth->setEnabled(false);
    customHeight->setEnabled(false);
    form->addRow(QObject::tr("Custom width"), customWidth);
    form->addRow(QObject::tr("Custom height"), customHeight);
    QObject::connect(resolution,
                     QOverload<int>::of(&QComboBox::currentIndexChanged),
                     &dialog,
                     [=]() {
        const bool custom = resolution->currentData().toInt() == -1;
        customWidth->setEnabled(custom);
        customHeight->setEnabled(custom);
    });

    auto* duration = new QSpinBox(&dialog);
    duration->setRange(5, 120);
    duration->setValue(type == RecordingSettings::OutputType::Gif ? 30 : 120);
    duration->setSuffix(QObject::tr(" seconds"));
    form->addRow(QObject::tr("Maximum duration"), duration);

    QComboBox* codec = nullptr;
    QComboBox* bitRate = nullptr;
    QSpinBox* customBitRate = nullptr;
    QCheckBox* systemAudio = nullptr;
    QCheckBox* microphone = nullptr;
    QComboBox* microphoneDevice = nullptr;
    QSpinBox* loopCount = nullptr;
    if (type == RecordingSettings::OutputType::Gif) {
        loopCount = new QSpinBox(&dialog);
        loopCount->setRange(0, 100);
        loopCount->setSpecialValueText(QObject::tr("Infinite"));
        form->addRow(QObject::tr("Loop count"), loopCount);
    }
    if (type == RecordingSettings::OutputType::Video) {
        codec = new QComboBox(&dialog);
        codec->addItem(QStringLiteral("H.264"), 0);
        codec->addItem(QStringLiteral("HEVC"), 1);
        form->addRow(QObject::tr("Codec"), codec);
        bitRate = new QComboBox(&dialog);
        bitRate->addItem(QObject::tr("Automatic"), 0);
        for (int value : { 4, 8, 16 }) {
            bitRate->addItem(QStringLiteral("%1 Mbps").arg(value), value);
        }
        bitRate->addItem(QObject::tr("Custom"), -1);
        form->addRow(QObject::tr("Bit rate"), bitRate);
        customBitRate = new QSpinBox(&dialog);
        customBitRate->setRange(1, 200);
        customBitRate->setSuffix(QStringLiteral(" Mbps"));
        customBitRate->setEnabled(false);
        form->addRow(QObject::tr("Custom bit rate"), customBitRate);
        QObject::connect(bitRate,
                         QOverload<int>::of(&QComboBox::currentIndexChanged),
                         &dialog,
                         [=]() { customBitRate->setEnabled(bitRate->currentData().toInt() == -1); });
        systemAudio = new QCheckBox(QObject::tr("Record system audio"), &dialog);
        systemAudio->setChecked(RecordingService::systemAudioAvailable());
        systemAudio->setEnabled(RecordingService::systemAudioAvailable());
        form->addRow(QString(), systemAudio);
        microphone = new QCheckBox(QObject::tr("Record microphone"), &dialog);
        form->addRow(QString(), microphone);
        microphoneDevice = new QComboBox(&dialog);
        for (const auto& device : RecordingService::audioInputDevices()) {
            microphoneDevice->addItem(device.first, device.second);
        }
        microphoneDevice->setEnabled(false);
        form->addRow(QObject::tr("Microphone"), microphoneDevice);
        QObject::connect(microphone, &QCheckBox::toggled,
                         microphoneDevice, &QComboBox::setEnabled);
    }

    auto* cursor = new QCheckBox(QObject::tr("Show mouse cursor"), &dialog);
    cursor->setChecked(true);
    form->addRow(QString(), cursor);
    auto* clicks = new QCheckBox(QObject::tr("Highlight mouse clicks"), &dialog);
    clicks->setEnabled(QOperatingSystemVersion::current() >=
                       QOperatingSystemVersion(QOperatingSystemVersion::MacOS, 15));
    if (!clicks->isEnabled()) {
        clicks->setToolTip(QObject::tr("Mouse click highlighting requires macOS 15 or later."));
    }
    form->addRow(QString(), clicks);

    QSettings persisted;
    const QString group = type == RecordingSettings::OutputType::Gif
      ? QStringLiteral("gifRecording")
      : QStringLiteral("videoRecording");
    persisted.beginGroup(group);
    const int savedFps = persisted.value(QStringLiteral("frameRate"),
                                         type == RecordingSettings::OutputType::Gif ? 10 : 30).toInt();
    const int fpsIndex = fps->findData(savedFps);
    if (fpsIndex >= 0) fps->setCurrentIndex(fpsIndex);
    const int savedResolution = persisted.value(QStringLiteral("longEdge"), 0).toInt();
    const int resolutionIndex = resolution->findData(savedResolution);
    if (resolutionIndex >= 0) resolution->setCurrentIndex(resolutionIndex);
    customWidth->setValue(persisted.value(QStringLiteral("customWidth"), 1920).toInt());
    customHeight->setValue(persisted.value(QStringLiteral("customHeight"), 1080).toInt());
    duration->setValue(persisted.value(QStringLiteral("duration"),
                                       type == RecordingSettings::OutputType::Gif ? 30 : 120).toInt());
    cursor->setChecked(persisted.value(QStringLiteral("cursor"), true).toBool());
    clicks->setChecked(persisted.value(QStringLiteral("clicks"), false).toBool());
    if (loopCount) loopCount->setValue(persisted.value(QStringLiteral("loops"), 0).toInt());
    if (codec) codec->setCurrentIndex(persisted.value(QStringLiteral("codec"), 0).toInt());
    if (bitRate) {
        const int index = bitRate->findData(persisted.value(QStringLiteral("bitRateMode"), 0));
        if (index >= 0) bitRate->setCurrentIndex(index);
    }
    if (customBitRate) customBitRate->setValue(persisted.value(QStringLiteral("customBitRate"), 12).toInt());
    if (systemAudio) {
        systemAudio->setChecked(RecordingService::systemAudioAvailable() &&
                                persisted.value(QStringLiteral("systemAudio"), true).toBool());
    }
    if (microphone) microphone->setChecked(persisted.value(QStringLiteral("microphone"), false).toBool());
    if (microphoneDevice) {
        const int index = microphoneDevice->findData(
          persisted.value(QStringLiteral("microphoneDevice")));
        if (index >= 0) microphoneDevice->setCurrentIndex(index);
        microphoneDevice->setEnabled(microphone->isChecked());
    }
    persisted.endGroup();

    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Ok |
                                           QDialogButtonBox::Cancel,
                                         &dialog);
    QObject::connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    QObject::connect(buttons, &QDialogButtonBox::rejected, &dialog, &QDialog::reject);
    layout->addWidget(buttons);
    if (dialog.exec() != QDialog::Accepted) {
        return false;
    }

    settings->outputType = type;
    settings->frameRate = fps->currentData().toInt();
    settings->longEdge = resolution->currentData().toInt();
    settings->customWidth = customWidth->value();
    settings->customHeight = customHeight->value();
    settings->maxDurationSeconds = duration->value();
    settings->showCursor = cursor->isChecked();
    settings->highlightClicks = clicks->isChecked();
    if (loopCount) settings->gifLoopCount = loopCount->value();
    if (type == RecordingSettings::OutputType::Video) {
        settings->codec = codec->currentData().toInt() == 0
          ? RecordingSettings::Codec::H264
          : RecordingSettings::Codec::HEVC;
        settings->bitRateMbps = bitRate->currentData().toInt() == -1
          ? customBitRate->value()
          : bitRate->currentData().toInt();
        settings->captureSystemAudio = systemAudio->isChecked();
        settings->captureMicrophone = microphone->isChecked();
        settings->microphoneDeviceId = microphoneDevice->currentData().toString();
    }
    persisted.beginGroup(group);
    persisted.setValue(QStringLiteral("frameRate"), settings->frameRate);
    persisted.setValue(QStringLiteral("longEdge"), settings->longEdge);
    persisted.setValue(QStringLiteral("customWidth"), settings->customWidth);
    persisted.setValue(QStringLiteral("customHeight"), settings->customHeight);
    persisted.setValue(QStringLiteral("duration"), settings->maxDurationSeconds);
    persisted.setValue(QStringLiteral("cursor"), settings->showCursor);
    persisted.setValue(QStringLiteral("clicks"), settings->highlightClicks);
    persisted.setValue(QStringLiteral("loops"), settings->gifLoopCount);
    persisted.setValue(QStringLiteral("codec"), settings->codec == RecordingSettings::Codec::HEVC ? 1 : 0);
    persisted.setValue(QStringLiteral("bitRateMode"), bitRate ? bitRate->currentData() : 0);
    persisted.setValue(QStringLiteral("customBitRate"), customBitRate ? customBitRate->value() : 12);
    persisted.setValue(QStringLiteral("systemAudio"), settings->captureSystemAudio);
    persisted.setValue(QStringLiteral("microphone"), settings->captureMicrophone);
    persisted.setValue(QStringLiteral("microphoneDevice"), settings->microphoneDeviceId);
    persisted.endGroup();
    return true;
}
