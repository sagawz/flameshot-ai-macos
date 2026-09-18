// SPDX-License-Identifier: GPL-3.0-or-later
#include "smartactiontool.h"

SmartActionTool::SmartActionTool(CaptureTool::Type type, QObject* parent)
  : AbstractActionTool(parent)
  , m_type(type)
{}

bool SmartActionTool::closeOnButtonPressed() const
{
    return false;
}

QIcon SmartActionTool::icon(const QColor& background, bool inEditor) const
{
    Q_UNUSED(inEditor)
    const char* iconName = m_type == TYPE_QRCODE ? "qr-code.svg"
                          : m_type == TYPE_AI_SUMMARY ? "ai-summary.svg"
                                                      : "translate.svg";
    return QIcon(iconPath(background) + iconName);
}

QString SmartActionTool::name() const
{
    switch (m_type) {
        case TYPE_TRANSLATE:
            return tr("Translate");
        case TYPE_QRCODE:
            return tr("QR code");
        case TYPE_AI_SUMMARY:
            return tr("AI summary");
        default:
            return {};
    }
}

QString SmartActionTool::description() const
{
    switch (m_type) {
        case TYPE_TRANSLATE:
            return tr("Recognize and translate text in the selection");
        case TYPE_QRCODE:
            return tr("Recognize QR codes in the selection");
        case TYPE_AI_SUMMARY:
            return tr("Summarize text in the selection with AI");
        default:
            return {};
    }
}

CaptureTool* SmartActionTool::copy(QObject* parent)
{
    return new SmartActionTool(m_type, parent);
}

CaptureTool::Type SmartActionTool::type() const
{
    return m_type;
}

void SmartActionTool::pressed(CaptureContext& context)
{
    Q_UNUSED(context)
    if (m_type == TYPE_TRANSLATE) {
        emit requestAction(REQ_TRANSLATE_SELECTION);
    } else if (m_type == TYPE_QRCODE) {
        emit requestAction(REQ_RECOGNIZE_QR);
    } else if (m_type == TYPE_AI_SUMMARY) {
        emit requestAction(REQ_AI_SUMMARY);
    }
}
