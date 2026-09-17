// SPDX-License-Identifier: GPL-3.0-or-later
#include "aiservice.h"
#include "src/widgets/textresultdialog.h"
#if defined(Q_OS_MACOS)
#include "src/utils/macwindowutils.h"
#endif

#include <QCoreApplication>
#include <QInputDialog>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLineEdit>
#include <QMessageBox>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProgressDialog>
#include <QProcessEnvironment>
#include <QUrl>

AiService::AiService(QObject* parent)
  : QObject(parent)
{}

QString AiService::requestApiKey(QWidget* parentWindow) const
{
    QString key = qEnvironmentVariable("OPENAI_API_KEY").trimmed();
    if (!key.isEmpty()) {
        return key;
    }
    QInputDialog dialog(parentWindow);
    dialog.setWindowTitle(tr("OpenAI API key"));
    dialog.setLabelText(
      tr("Enter an API key for this request. The key is not saved:"));
    dialog.setTextEchoMode(QLineEdit::Password);
    dialog.setWindowFlag(Qt::WindowStaysOnTopHint, true);
    dialog.show();
#if defined(Q_OS_MACOS)
    configureMacCaptureWindow(&dialog);
#endif
    return dialog.exec() == QDialog::Accepted ? dialog.textValue().trimmed()
                                               : QString();
}

void AiService::run(Task task,
                    const QString& recognizedText,
                    QWidget* parentWindow)
{
    if (recognizedText.trimmed().isEmpty()) {
        QMessageBox::information(parentWindow,
                                 tr("No text found"),
                                 tr("No recognizable text was found in the selection."));
        return;
    }
    const QString apiKey = requestApiKey(parentWindow);
    if (apiKey.isEmpty()) {
        return;
    }

    const QString model = qEnvironmentVariable("OPENAI_MODEL", "gpt-5.6-terra");
    const QString baseUrl =
      qEnvironmentVariable("OPENAI_BASE_URL", "https://api.openai.com/v1");
    const QString instruction = task == Task::Translate
      ? tr("Translate the following recognized screenshot text into Simplified Chinese. "
           "Preserve names, numbers, URLs, formatting, and code. Return only the translation.")
      : tr("Summarize the following recognized screenshot text in Simplified Chinese. "
           "Lead with the conclusion, then list key facts and action items. Do not invent facts.");

    QJsonObject inputText{ { "type", "input_text" },
                           { "text", instruction + "\n\n" + recognizedText } };
    QJsonObject message{ { "role", "user" },
                         { "content", QJsonArray{ inputText } } };
    QJsonObject body{ { "model", model },
                      { "input", QJsonArray{ message } },
                      { "text", QJsonObject{ { "verbosity", "low" } } } };

    auto* manager = new QNetworkAccessManager(this);
    QNetworkRequest request{ QUrl(baseUrl + "/responses") };
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", "Bearer " + apiKey.toUtf8());
    auto* progress = new QProgressDialog(tr("Processing with AI…"),
                                         tr("Cancel"),
                                         0,
                                         0,
                                         parentWindow);
    progress->setWindowModality(Qt::WindowModal);
    progress->setMinimumDuration(0);
    progress->setWindowFlag(Qt::WindowStaysOnTopHint, true);
    progress->show();
#if defined(Q_OS_MACOS)
    configureMacCaptureWindow(progress);
#endif
    QNetworkReply* reply = manager->post(request, QJsonDocument(body).toJson());
    connect(progress, &QProgressDialog::canceled, reply, &QNetworkReply::abort);
    connect(reply, &QNetworkReply::finished, this, [=]() {
        progress->close();
        progress->deleteLater();
        const QByteArray payload = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            QMessageBox::critical(parentWindow,
                                  tr("AI request failed"),
                                  reply->errorString() + "\n" +
                                    QString::fromUtf8(payload.left(1200)));
        } else {
            const QJsonObject root = QJsonDocument::fromJson(payload).object();
            QString result;
            for (const QJsonValue& outputValue : root.value("output").toArray()) {
                for (const QJsonValue& contentValue :
                     outputValue.toObject().value("content").toArray()) {
                    const QJsonObject content = contentValue.toObject();
                    if (content.value("type").toString() == "output_text") {
                        result += content.value("text").toString();
                    }
                }
            }
            if (result.trimmed().isEmpty()) {
                QMessageBox::warning(parentWindow,
                                     tr("Empty AI response"),
                                     tr("The service returned no text."));
            } else {
                auto* dialog = new TextResultDialog(
                  task == Task::Translate ? tr("Translation") : tr("AI summary"),
                  result,
                  parentWindow);
                dialog->setAttribute(Qt::WA_DeleteOnClose);
                dialog->show();
#if defined(Q_OS_MACOS)
                configureMacCaptureWindow(dialog);
#endif
            }
        }
        reply->deleteLater();
        manager->deleteLater();
    });
}
