// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QString>

class QWidget;

class AiService : public QObject
{
    Q_OBJECT
public:
    enum class Task
    {
        Translate,
        Summarize
    };

    explicit AiService(QObject* parent = nullptr);
    void run(Task task, const QString& recognizedText, QWidget* parentWindow);

private:
};
