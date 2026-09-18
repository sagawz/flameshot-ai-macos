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

namespace {
struct AiConfig
{
    QString apiKey;
    QString baseUrl;
    QString model;
    bool useResponsesApi = false;
};

void prepareDialog(QInputDialog& dialog, QWidget* parentWindow)
{
    Q_UNUSED(parentWindow)
    dialog.setWindowFlag(Qt::WindowStaysOnTopHint, true);
    dialog.show();
#if defined(Q_OS_MACOS)
    configureMacCaptureWindow(&dialog);
#endif
}

QString normalizedBaseUrl(QString value)
{
    value = value.trimmed();
    while (value.endsWith('/')) {
        value.chop(1);
    }
    return value;
}
}

AiService::AiService(QObject* parent)
  : QObject(parent)
{}

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
    AiConfig config;
    config.apiKey = qEnvironmentVariable("AI_API_KEY").trimmed();
    config.baseUrl = qEnvironmentVariable("AI_BASE_URL").trimmed();
    config.model = qEnvironmentVariable("AI_MODEL").trimmed();
    QString apiStyle = qEnvironmentVariable("AI_API_STYLE").trimmed().toLower();

    if (config.apiKey.isEmpty()) {
        const QString deepSeekKey =
          qEnvironmentVariable("DEEPSEEK_API_KEY").trimmed();
        const QString openAiKey = qEnvironmentVariable("OPENAI_API_KEY").trimmed();
        if (!deepSeekKey.isEmpty()) {
            config.apiKey = deepSeekKey;
            config.baseUrl = config.baseUrl.isEmpty()
              ? QStringLiteral("https://api.deepseek.com/v1")
              : config.baseUrl;
            config.model = config.model.isEmpty()
              ? QStringLiteral("deepseek-chat")
              : config.model;
            apiStyle = QStringLiteral("chat_completions");
        } else if (!openAiKey.isEmpty()) {
            config.apiKey = openAiKey;
            config.baseUrl = config.baseUrl.isEmpty()
              ? qEnvironmentVariable("OPENAI_BASE_URL",
                                     "https://api.openai.com/v1")
              : config.baseUrl;
            config.model = config.model.isEmpty()
              ? qEnvironmentVariable("OPENAI_MODEL", "gpt-5.6-terra")
              : config.model;
            apiStyle = apiStyle.isEmpty() ? QStringLiteral("responses") : apiStyle;
        }
    }

    if (config.apiKey.isEmpty()) {
        QInputDialog providerDialog(parentWindow);
        providerDialog.setWindowTitle(tr("AI service"));
        providerDialog.setLabelText(tr("Choose the service for this request:"));
        providerDialog.setComboBoxItems(
          { tr("DeepSeek"), tr("OpenAI"), tr("Other compatible service") });
        providerDialog.setComboBoxEditable(false);
        prepareDialog(providerDialog, parentWindow);
        if (providerDialog.exec() != QDialog::Accepted) {
            return;
        }
        const int provider = providerDialog.comboBoxItems().indexOf(
          providerDialog.textValue());
        if (provider == 0) {
            config.baseUrl = QStringLiteral("https://api.deepseek.com/v1");
            config.model = QStringLiteral("deepseek-chat");
            apiStyle = QStringLiteral("chat_completions");
        } else if (provider == 1) {
            config.baseUrl = QStringLiteral("https://api.openai.com/v1");
            config.model = QStringLiteral("gpt-5.6-terra");
            apiStyle = QStringLiteral("responses");
        } else {
            QInputDialog urlDialog(parentWindow);
            urlDialog.setWindowTitle(tr("Compatible AI service"));
            urlDialog.setLabelText(tr("API base URL (including /v1):"));
            urlDialog.setTextValue(QStringLiteral("https://example.com/v1"));
            prepareDialog(urlDialog, parentWindow);
            if (urlDialog.exec() != QDialog::Accepted) {
                return;
            }
            config.baseUrl = urlDialog.textValue();

            QInputDialog modelDialog(parentWindow);
            modelDialog.setWindowTitle(tr("Compatible AI service"));
            modelDialog.setLabelText(tr("Model name:"));
            prepareDialog(modelDialog, parentWindow);
            if (modelDialog.exec() != QDialog::Accepted) {
                return;
            }
            config.model = modelDialog.textValue().trimmed();
            apiStyle = QStringLiteral("chat_completions");
        }

        QInputDialog keyDialog(parentWindow);
        keyDialog.setWindowTitle(tr("AI API key"));
        keyDialog.setLabelText(
          tr("Enter the API key for this request. The key is not saved:"));
        keyDialog.setTextEchoMode(QLineEdit::Password);
        prepareDialog(keyDialog, parentWindow);
        if (keyDialog.exec() != QDialog::Accepted) {
            return;
        }
        config.apiKey = keyDialog.textValue().trimmed();
    }

    config.baseUrl = normalizedBaseUrl(config.baseUrl);
    config.useResponsesApi = apiStyle == QStringLiteral("responses");
    if (config.apiKey.isEmpty() || config.baseUrl.isEmpty() ||
        config.model.isEmpty()) {
        QMessageBox::warning(parentWindow,
                             tr("AI configuration incomplete"),
                             tr("API key, base URL, and model are required."));
        return;
    }
    const QString instruction = task == Task::Translate
      ? tr("Translate the following recognized screenshot text into Simplified Chinese. "
           "Preserve names, numbers, URLs, formatting, and code. Return only the translation.")
      : tr("Summarize the following recognized screenshot text in Simplified Chinese. "
           "Lead with the conclusion, then list key facts and action items. Do not invent facts.");

    const QString prompt = instruction + "\n\n" + recognizedText;
    QJsonObject body;
    if (config.useResponsesApi) {
        QJsonObject inputText{ { "type", "input_text" }, { "text", prompt } };
        QJsonObject message{ { "role", "user" },
                             { "content", QJsonArray{ inputText } } };
        body = QJsonObject{ { "model", config.model },
                            { "input", QJsonArray{ message } },
                            { "text", QJsonObject{ { "verbosity", "low" } } } };
    } else {
        QJsonObject message{ { "role", "user" }, { "content", prompt } };
        body = QJsonObject{ { "model", config.model },
                            { "messages", QJsonArray{ message } },
                            { "stream", false } };
    }

    auto* manager = new QNetworkAccessManager(this);
    QNetworkRequest request{ QUrl(config.baseUrl +
                                  (config.useResponsesApi
                                     ? QStringLiteral("/responses")
                                     : QStringLiteral("/chat/completions"))) };
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", "Bearer " + config.apiKey.toUtf8());
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
            if (config.useResponsesApi) {
                for (const QJsonValue& outputValue :
                     root.value("output").toArray()) {
                    for (const QJsonValue& contentValue :
                         outputValue.toObject().value("content").toArray()) {
                        const QJsonObject content = contentValue.toObject();
                        if (content.value("type").toString() == "output_text") {
                            result += content.value("text").toString();
                        }
                    }
                }
            } else {
                const QJsonArray choices = root.value("choices").toArray();
                if (!choices.isEmpty()) {
                    result = choices.first()
                               .toObject()
                               .value("message")
                               .toObject()
                               .value("content")
                               .toString();
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
