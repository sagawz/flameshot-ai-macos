// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QDialog>

class TextResultDialog : public QDialog
{
    Q_OBJECT
public:
    TextResultDialog(const QString& title,
                     const QString& text,
                     QWidget* parent = nullptr);
};
