// SPDX-License-Identifier: GPL-3.0-or-later
#include "recordingcontrolwidget.h"
#include "src/utils/macwindowutils.h"

#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>

RecordingControlWidget::RecordingControlWidget(QWidget* parent)
  : QWidget(parent)
  , m_timeLabel(new QLabel(QStringLiteral("00:00"), this))
  , m_pauseButton(new QPushButton(tr("Pause"), this))
{
    setWindowFlag(Qt::Tool, true);
    setWindowFlag(Qt::WindowStaysOnTopHint, true);
    setAttribute(Qt::WA_DeleteOnClose, false);
    auto* layout = new QHBoxLayout(this);
    layout->setContentsMargins(10, 6, 10, 6);
    layout->addWidget(new QLabel(tr("Recording"), this));
    layout->addWidget(m_timeLabel);
    layout->addWidget(m_pauseButton);
    auto* stop = new QPushButton(tr("Stop"), this);
    auto* cancel = new QPushButton(tr("Cancel"), this);
    layout->addWidget(stop);
    layout->addWidget(cancel);
    connect(m_pauseButton, &QPushButton::clicked, this, [this]() {
        m_paused ? emit resumeRequested() : emit pauseRequested();
    });
    connect(stop, &QPushButton::clicked, this, &RecordingControlWidget::stopRequested);
    connect(cancel, &QPushButton::clicked, this, &RecordingControlWidget::cancelRequested);
}

void RecordingControlWidget::reset()
{
    setPaused(false);
    setElapsed(0);
}

void RecordingControlWidget::setPaused(bool paused)
{
    m_paused = paused;
    m_pauseButton->setText(paused ? tr("Resume") : tr("Pause"));
}

void RecordingControlWidget::setElapsed(qint64 milliseconds)
{
    const qint64 seconds = milliseconds / 1000;
    m_timeLabel->setText(QStringLiteral("%1:%2")
                           .arg(seconds / 60, 2, 10, QLatin1Char('0'))
                           .arg(seconds % 60, 2, 10, QLatin1Char('0')));
}
