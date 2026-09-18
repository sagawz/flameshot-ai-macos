// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QWidget>

class QLabel;
class QPushButton;
class QTimer;

class RecordingControlWidget : public QWidget
{
    Q_OBJECT
public:
    explicit RecordingControlWidget(QWidget* parent = nullptr);
    void reset();

signals:
    void pauseRequested();
    void resumeRequested();
    void stopRequested();
    void cancelRequested();

public slots:
    void setPaused(bool paused);
    void setElapsed(qint64 milliseconds);

private:
    QLabel* m_timeLabel;
    QPushButton* m_pauseButton;
    bool m_paused = false;
};
