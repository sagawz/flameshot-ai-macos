// SPDX-License-Identifier: GPL-3.0-or-later
#include "nativevisionservice.h"

#include <QBuffer>
#include <QByteArray>

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <Vision/Vision.h>

namespace {
CGImageRef imageRef(const QImage& image)
{
    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    if (!image.save(&buffer, "PNG")) {
        return nullptr;
    }
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                  reinterpret_cast<const UInt8*>(png.constData()),
                                  png.size());
    CGImageSourceRef source = CGImageSourceCreateWithData(data, nullptr);
    CGImageRef result = source ? CGImageSourceCreateImageAtIndex(source, 0, nullptr)
                               : nullptr;
    if (source) {
        CFRelease(source);
    }
    CFRelease(data);
    return result;
}

QString errorString(NSError* error)
{
    return error ? QString::fromUtf8(error.localizedDescription.UTF8String)
                 : QString();
}
}

bool NativeVisionService::isAvailable()
{
    if (@available(macOS 10.15, *)) {
        return true;
    }
    return false;
}

QString NativeVisionService::recognizeText(const QImage& image, QString* error)
{
    if (!isAvailable()) {
        if (error) {
            *error = QStringLiteral("macOS 10.15 or newer is required for OCR.");
        }
        return {};
    }

    CGImageRef cgImage = imageRef(image);
    if (!cgImage) {
        if (error) {
            *error = QStringLiteral("Unable to prepare the selected image.");
        }
        return {};
    }

    __block NSMutableArray<NSString*>* lines = [NSMutableArray array];
    __block NSError* requestError = nil;
    VNRecognizeTextRequest* request = [[VNRecognizeTextRequest alloc]
      initWithCompletionHandler:^(VNRequest* completed, NSError* visionError) {
        requestError = visionError;
        for (VNRecognizedTextObservation* observation in completed.results) {
            VNRecognizedText* candidate = [observation topCandidates:1].firstObject;
            if (candidate.string.length > 0) {
                [lines addObject:candidate.string];
            }
        }
      }];
    request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    request.recognitionLanguages = @[ @"zh-Hans", @"zh-Hant", @"en-US" ];
    request.usesLanguageCorrection = YES;

    VNImageRequestHandler* handler =
      [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    NSError* performError = nil;
    [handler performRequests:@[ request ] error:&performError];
    CGImageRelease(cgImage);

    NSError* finalError = performError ?: requestError;
    if (finalError && error) {
        *error = errorString(finalError);
    }
    return QString::fromUtf8([[lines componentsJoinedByString:@"\n"] UTF8String]);
}

QStringList NativeVisionService::recognizeQRCodes(const QImage& image,
                                                   QString* error)
{
    QStringList values;
    CGImageRef cgImage = imageRef(image);
    if (!cgImage) {
        if (error) {
            *error = QStringLiteral("Unable to prepare the selected image.");
        }
        return values;
    }

    __block NSMutableArray<NSString*>* payloads = [NSMutableArray array];
    __block NSError* requestError = nil;
    VNDetectBarcodesRequest* request = [[VNDetectBarcodesRequest alloc]
      initWithCompletionHandler:^(VNRequest* completed, NSError* visionError) {
        requestError = visionError;
        for (VNBarcodeObservation* observation in completed.results) {
            if ([observation.symbology isEqualToString:VNBarcodeSymbologyQR] &&
                observation.payloadStringValue.length > 0) {
                [payloads addObject:observation.payloadStringValue];
            }
        }
      }];
    request.symbologies = @[ VNBarcodeSymbologyQR ];
    VNImageRequestHandler* handler =
      [[VNImageRequestHandler alloc] initWithCGImage:cgImage options:@{}];
    NSError* performError = nil;
    [handler performRequests:@[ request ] error:&performError];
    CGImageRelease(cgImage);

    NSError* finalError = performError ?: requestError;
    if (finalError && error) {
        *error = errorString(finalError);
    }
    for (NSString* payload in payloads) {
        values.append(QString::fromUtf8(payload.UTF8String));
    }
    values.removeDuplicates();
    return values;
}
