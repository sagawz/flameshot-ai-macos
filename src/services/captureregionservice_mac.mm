// SPDX-License-Identifier: GPL-3.0-or-later
#include "captureregionservice.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QScreen>

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

namespace {
QRect rectFromDictionary(CFDictionaryRef dictionary)
{
    CGRect rect = CGRectZero;
    if (dictionary) {
        CGRectMakeWithDictionaryRepresentation(dictionary, &rect);
    }
    return QRect(qRound(rect.origin.x),
                 qRound(rect.origin.y),
                 qRound(rect.size.width),
                 qRound(rect.size.height));
}

QString axString(AXUIElementRef element, CFStringRef attribute)
{
    CFTypeRef value = nullptr;
    if (AXUIElementCopyAttributeValue(element, attribute, &value) !=
          kAXErrorSuccess ||
        !value) {
        return {};
    }
    QString result;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = QString::fromCFString(static_cast<CFStringRef>(value));
    }
    CFRelease(value);
    return result;
}

QRect axRect(AXUIElementRef element)
{
    CFTypeRef positionValue = nullptr;
    CFTypeRef sizeValue = nullptr;
    CGPoint position = CGPointZero;
    CGSize size = CGSizeZero;
    const bool valid =
      AXUIElementCopyAttributeValue(element, kAXPositionAttribute,
                                    &positionValue) == kAXErrorSuccess &&
      AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &sizeValue) ==
        kAXErrorSuccess &&
      positionValue && sizeValue &&
      AXValueGetValue(static_cast<AXValueRef>(positionValue),
                      static_cast<AXValueType>(kAXValueCGPointType),
                      &position) &&
      AXValueGetValue(static_cast<AXValueRef>(sizeValue),
                      static_cast<AXValueType>(kAXValueCGSizeType),
                      &size);
    if (positionValue) {
        CFRelease(positionValue);
    }
    if (sizeValue) {
        CFRelease(sizeValue);
    }
    return valid ? QRect(qRound(position.x),
                         qRound(position.y),
                         qRound(size.width),
                         qRound(size.height))
                 : QRect();
}

bool usefulRect(const QRect& rect)
{
    return rect.width() >= 16 && rect.height() >= 16 &&
           rect.width() < 20000 && rect.height() < 20000;
}

void appendAccessibilityCandidates(QVector<CaptureRegionCandidate>& output,
                                   const QPoint& globalPos)
{
    AXUIElementRef system = AXUIElementCreateSystemWide();
    AXUIElementRef element = nullptr;
    if (AXUIElementCopyElementAtPosition(system,
                                         globalPos.x(),
                                         globalPos.y(),
                                         &element) != kAXErrorSuccess ||
        !element) {
        CFRelease(system);
        return;
    }

    int depth = 0;
    while (element && depth++ < 12) {
        const QRect geometry = axRect(element);
        const QString role = axString(element, kAXRoleAttribute);
        if (usefulRect(geometry) && geometry.contains(globalPos)) {
            CaptureRegionCandidate candidate;
            candidate.geometry = geometry;
            candidate.role = role;
            candidate.priority = geometry.width() * geometry.height();
            if (role == QStringLiteral("AXWindow") ||
                role == QStringLiteral("AXSheet") ||
                role == QStringLiteral("AXDialog")) {
                candidate.type = CaptureRegionCandidate::Type::Dialog;
            } else {
                candidate.type = CaptureRegionCandidate::Type::Control;
            }
            bool duplicate = false;
            for (const auto& existing : output) {
                duplicate |= existing.geometry == candidate.geometry;
            }
            if (!duplicate) {
                output.append(candidate);
            }
        }

        CFTypeRef parentValue = nullptr;
        if (AXUIElementCopyAttributeValue(element,
                                          kAXParentAttribute,
                                          &parentValue) != kAXErrorSuccess ||
            !parentValue) {
            CFRelease(element);
            element = nullptr;
            break;
        }
        CFRelease(element);
        element = static_cast<AXUIElementRef>(parentValue);
    }
    if (element) {
        CFRelease(element);
    }
    CFRelease(system);
}
}

bool CaptureRegionService::accessibilityTrusted(bool prompt)
{
    if (!prompt) {
        return AXIsProcessTrusted();
    }
    NSDictionary* options = @{ (__bridge NSString*)kAXTrustedCheckOptionPrompt : @YES };
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

QVector<CaptureRegionCandidate> CaptureRegionService::candidatesAt(
  const QPoint& globalPos)
{
    QVector<CaptureRegionCandidate> result;
    if (accessibilityTrusted(false)) {
        appendAccessibilityCandidates(result, globalPos);
    }

    CFArrayRef windows = CGWindowListCopyWindowInfo(
      kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
      kCGNullWindowID);
    const pid_t ownPid = QCoreApplication::applicationPid();
    if (windows) {
        const CFIndex count = CFArrayGetCount(windows);
        for (CFIndex index = 0; index < count; ++index) {
            auto dictionary = static_cast<CFDictionaryRef>(
              CFArrayGetValueAtIndex(windows, index));
            int64_t ownerPid = 0;
            int64_t windowId = 0;
            int64_t layer = 0;
            double alpha = 0;
            CFNumberGetValue(static_cast<CFNumberRef>(CFDictionaryGetValue(
                               dictionary, kCGWindowOwnerPID)),
                             kCFNumberSInt64Type,
                             &ownerPid);
            CFNumberGetValue(static_cast<CFNumberRef>(CFDictionaryGetValue(
                               dictionary, kCGWindowNumber)),
                             kCFNumberSInt64Type,
                             &windowId);
            CFNumberGetValue(static_cast<CFNumberRef>(CFDictionaryGetValue(
                               dictionary, kCGWindowLayer)),
                             kCFNumberSInt64Type,
                             &layer);
            CFNumberGetValue(static_cast<CFNumberRef>(CFDictionaryGetValue(
                               dictionary, kCGWindowAlpha)),
                             kCFNumberDoubleType,
                             &alpha);
            const QRect geometry = rectFromDictionary(
              static_cast<CFDictionaryRef>(CFDictionaryGetValue(
                dictionary, kCGWindowBounds)));
            if (ownerPid == ownPid || layer != 0 || alpha < 0.05 ||
                !usefulRect(geometry) || !geometry.contains(globalPos)) {
                continue;
            }
            CaptureRegionCandidate candidate;
            candidate.geometry = geometry;
            candidate.type = CaptureRegionCandidate::Type::Window;
            candidate.windowId = windowId;
            candidate.priority = geometry.width() * geometry.height();
            if (auto name = static_cast<CFStringRef>(CFDictionaryGetValue(
                  dictionary, kCGWindowOwnerName))) {
                candidate.applicationName = QString::fromCFString(name);
            }
            result.append(candidate);
        }
        CFRelease(windows);
    }

    if (QScreen* screen = QGuiApplication::screenAt(globalPos)) {
        CaptureRegionCandidate screenCandidate;
        screenCandidate.geometry = screen->geometry();
        screenCandidate.type = CaptureRegionCandidate::Type::Screen;
        screenCandidate.role = QStringLiteral("Screen");
        screenCandidate.priority = INT_MAX;
        result.append(screenCandidate);
    }

    std::stable_sort(result.begin(), result.end(), [](const auto& left,
                                                       const auto& right) {
        return left.priority < right.priority;
    });
    return result;
}
