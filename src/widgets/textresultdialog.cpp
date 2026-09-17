// SPDX-License-Identifier: GPL-3.0-or-later
#include "textresultdialog.h"

#include <QApplication>
#include <QClipboard>
#include <QDialogButtonBox>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QVBoxLayout>

TextResultDialog::TextResultDialog(const QString& title,
                                   const QString& text,
                                   QWidget* parent)
  : QDialog(parent)
{
    setWindowTitle(title);
    resize(620, 420);
    auto* layout = new QVBoxLayout(this);
    auto* editor = new QPlainTextEdit(text, this);
    editor->setReadOnly(true);
    layout->addWidget(editor);
    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Close, this);
    auto* copy = buttons->addButton(tr("Copy"), QDialogButtonBox::ActionRole);
    connect(copy, &QPushButton::clicked, this, [text]() {
        QApplication::clipboard()->setText(text);
    });
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::close);
    layout->addWidget(buttons);
}
