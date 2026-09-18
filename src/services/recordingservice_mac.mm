// SPDX-License-Identifier: GPL-3.0-or-later
#include "recordingservice.h"

#include <QFile>
#include <QMetaObject>
#include <QOperatingSystemVersion>

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <VideoToolbox/VideoToolbox.h>

static CMSampleBufferRef copyWithOffset(CMSampleBufferRef sample, CMTime offset)
{
    CMItemCount count = 0;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nullptr, &count);
    if (count <= 0) {
        return reinterpret_cast<CMSampleBufferRef>(
          const_cast<void*>(CFRetain(sample)));
    }
    auto* timing = new CMSampleTimingInfo[count];
    CMSampleBufferGetSampleTimingInfoArray(sample, count, timing, &count);
    for (CMItemCount index = 0; index < count; ++index) {
        if (CMTIME_IS_VALID(timing[index].presentationTimeStamp)) {
            timing[index].presentationTimeStamp =
              CMTimeSubtract(timing[index].presentationTimeStamp, offset);
        }
        if (CMTIME_IS_VALID(timing[index].decodeTimeStamp)) {
            timing[index].decodeTimeStamp =
              CMTimeSubtract(timing[index].decodeTimeStamp, offset);
        }
    }
    CMSampleBufferRef copy = nullptr;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
                                           sample,
                                           count,
                                           timing,
                                           &copy);
    delete[] timing;
    return copy;
}

API_AVAILABLE(macos(12.3))
@interface FlameshotRecordingBridge
    : NSObject <SCStreamOutput, SCStreamDelegate,
                AVCaptureAudioDataOutputSampleBufferDelegate>
@property(nonatomic, assign) RecordingService* owner;
@property(nonatomic, strong) SCStream* stream;
@property(nonatomic, strong) AVAssetWriter* writer;
@property(nonatomic, strong) AVAssetWriterInput* videoInput;
@property(nonatomic, strong) AVAssetWriterInput* systemAudioInput;
@property(nonatomic, strong) AVAssetWriterInput* microphoneInput;
@property(nonatomic, strong) AVCaptureSession* microphoneSession;
@property(nonatomic) CGImageDestinationRef gifDestination;
@property(nonatomic, copy) NSString* outputPath;
@property(nonatomic, assign) RecordingSettings settings;
@property(nonatomic, assign) BOOL recording;
@property(nonatomic, assign) BOOL paused;
@property(nonatomic, assign) BOOL cancelled;
@property(nonatomic, assign) BOOL sessionStarted;
@property(nonatomic, assign) CMTime firstPTS;
@property(nonatomic, assign) CMTime pauseStart;
@property(nonatomic, assign) CMTime pauseOffset;
@property(nonatomic, assign) NSInteger gifFrameCount;
@property(nonatomic, assign) NSInteger outputWidth;
@property(nonatomic, assign) NSInteger outputHeight;
@end

@implementation FlameshotRecordingBridge

- (void)reportFailure:(NSString*)message
{
    if (!self.recording) {
        return;
    }
    self.recording = NO;
    [self.microphoneSession stopRunning];
    if (self.gifDestination) {
        CFRelease(self.gifDestination);
        self.gifDestination = nullptr;
    }
    [[NSFileManager defaultManager] removeItemAtPath:self.outputPath error:nil];
    RecordingService* target = self.owner;
    if (!target) {
        return;
    }
    const QString text = QString::fromNSString(message ?: @"Unknown recording error");
    QMetaObject::invokeMethod(target, [target, text]() { emit target->failed(text); });
}

- (void)configureWriter
{
    NSURL* url = [NSURL fileURLWithPath:self.outputPath];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    NSError* error = nil;
    self.writer = [[AVAssetWriter alloc] initWithURL:url
                                            fileType:AVFileTypeMPEG4
                                               error:&error];
    if (!self.writer) {
        [self reportFailure:error.localizedDescription];
        return;
    }
    NSString* codec = self.settings.codec == RecordingSettings::Codec::HEVC
      ? AVVideoCodecTypeHEVC
      : AVVideoCodecTypeH264;
    NSMutableDictionary* compression = [NSMutableDictionary dictionary];
    if (self.settings.bitRateMbps > 0) {
        compression[AVVideoAverageBitRateKey] =
          @(self.settings.bitRateMbps * 1000 * 1000);
    }
    NSDictionary* videoSettings = @{
        AVVideoCodecKey : codec,
        AVVideoWidthKey : @(self.outputWidth),
        AVVideoHeightKey : @(self.outputHeight),
        AVVideoCompressionPropertiesKey : compression
    };
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                         outputSettings:videoSettings];
    self.videoInput.expectsMediaDataInRealTime = YES;
    if ([self.writer canAddInput:self.videoInput]) {
        [self.writer addInput:self.videoInput];
    }
    NSDictionary* audioSettings = @{
        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
        AVSampleRateKey : @48000,
        AVNumberOfChannelsKey : @2,
        AVEncoderBitRateKey : @192000
    };
    if (self.settings.captureSystemAudio) {
        self.systemAudioInput =
          [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                             outputSettings:audioSettings];
        self.systemAudioInput.expectsMediaDataInRealTime = YES;
        if ([self.writer canAddInput:self.systemAudioInput]) {
            [self.writer addInput:self.systemAudioInput];
        }
    }
    if (self.settings.captureMicrophone) {
        self.microphoneInput =
          [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                             outputSettings:audioSettings];
        self.microphoneInput.expectsMediaDataInRealTime = YES;
        if ([self.writer canAddInput:self.microphoneInput]) {
            [self.writer addInput:self.microphoneInput];
        }
    }
}

- (void)configureMicrophone
{
    if (!self.settings.captureMicrophone) {
        return;
    }
    AVCaptureDevice* device = nil;
    if (!self.settings.microphoneDeviceId.isEmpty()) {
        device = [AVCaptureDevice deviceWithUniqueID:
          self.settings.microphoneDeviceId.toNSString()];
    }
    if (!device) {
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    }
    NSError* error = nil;
    AVCaptureDeviceInput* input =
      device ? [AVCaptureDeviceInput deviceInputWithDevice:device error:&error] : nil;
    if (!input) {
        [self reportFailure:error.localizedDescription ?: @"Microphone is unavailable"];
        return;
    }
    self.microphoneSession = [[AVCaptureSession alloc] init];
    AVCaptureAudioDataOutput* output = [[AVCaptureAudioDataOutput alloc] init];
    [output setSampleBufferDelegate:self
                              queue:dispatch_queue_create("org.flameshot.ai.microphone",
                                                          DISPATCH_QUEUE_SERIAL)];
    if ([self.microphoneSession canAddInput:input]) {
        [self.microphoneSession addInput:input];
    }
    if ([self.microphoneSession canAddOutput:output]) {
        [self.microphoneSession addOutput:output];
    }
    [self.microphoneSession startRunning];
}

- (void)appendVideoSample:(CMSampleBufferRef)sample
{
    if (!self.sessionStarted) {
        self.firstPTS = CMSampleBufferGetPresentationTimeStamp(sample);
        if (self.settings.outputType == RecordingSettings::OutputType::Video) {
            if (![self.writer startWriting]) {
                [self reportFailure:self.writer.error.localizedDescription];
                return;
            }
            [self.writer startSessionAtSourceTime:self.firstPTS];
        }
        self.sessionStarted = YES;
        RecordingService* target = self.owner;
        QMetaObject::invokeMethod(target, [target]() { emit target->started(); });
    }
    const CMTime pts = CMSampleBufferGetPresentationTimeStamp(sample);
    const qint64 elapsed = qMax<qint64>(0,
      qRound64(CMTimeGetSeconds(CMTimeSubtract(CMTimeSubtract(pts, self.firstPTS),
                                               self.pauseOffset)) * 1000.0));
    RecordingService* target = self.owner;
    QMetaObject::invokeMethod(target, [target, elapsed]() {
        emit target->elapsedChanged(elapsed);
    });
    if (elapsed >= self.settings.maxDurationSeconds * 1000LL) {
        QMetaObject::invokeMethod(target, [target]() { target->stop(); });
        return;
    }

    if (self.settings.outputType == RecordingSettings::OutputType::Gif) {
        CVPixelBufferRef pixel = CMSampleBufferGetImageBuffer(sample);
        CGImageRef image = nullptr;
        if (pixel && VTCreateCGImageFromCVPixelBuffer(pixel, nullptr, &image) == noErr && image) {
            const double delay = 1.0 / qMax(1, self.settings.frameRate);
            NSDictionary* properties = @{
                (__bridge NSString*)kCGImagePropertyGIFDictionary : @{
                    (__bridge NSString*)kCGImagePropertyGIFDelayTime : @(delay),
                    (__bridge NSString*)kCGImagePropertyGIFUnclampedDelayTime : @(delay)
                }
            };
            CGImageDestinationAddImage(self.gifDestination,
                                       image,
                                       (__bridge CFDictionaryRef)properties);
            CGImageRelease(image);
            self.gifFrameCount++;
        }
        return;
    }
    if (self.videoInput.readyForMoreMediaData) {
        CMSampleBufferRef adjusted = copyWithOffset(sample, self.pauseOffset);
        [self.videoInput appendSampleBuffer:adjusted];
        CFRelease(adjusted);
    }
}

- (void)stream:(SCStream*)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sample
                   ofType:(SCStreamOutputType)type
{
    Q_UNUSED(stream)
    if (!self.recording || self.paused || !CMSampleBufferIsValid(sample)) {
        return;
    }
    if (type == SCStreamOutputTypeScreen) {
        [self appendVideoSample:sample];
    } else if (@available(macOS 13.0, *)) {
        if (type == SCStreamOutputTypeAudio && self.sessionStarted &&
            self.systemAudioInput.readyForMoreMediaData) {
            CMSampleBufferRef adjusted = copyWithOffset(sample, self.pauseOffset);
            [self.systemAudioInput appendSampleBuffer:adjusted];
            CFRelease(adjusted);
        }
    }
}

- (void)captureOutput:(AVCaptureOutput*)output
    didOutputSampleBuffer:(CMSampleBufferRef)sample
           fromConnection:(AVCaptureConnection*)connection
{
    Q_UNUSED(output)
    Q_UNUSED(connection)
    if (!self.recording || self.paused || !self.sessionStarted ||
        !self.microphoneInput.readyForMoreMediaData) {
        return;
    }
    CMSampleBufferRef adjusted = copyWithOffset(sample, self.pauseOffset);
    [self.microphoneInput appendSampleBuffer:adjusted];
    CFRelease(adjusted);
}

- (void)stream:(SCStream*)stream didStopWithError:(NSError*)error
{
    Q_UNUSED(stream)
    if (self.recording && error) {
        [self reportFailure:error.localizedDescription];
    }
}

- (void)finish
{
    if (!self.recording) {
        return;
    }
    self.recording = NO;
    [self.microphoneSession stopRunning];
    void (^finalizeOutput)(NSError*) = ^(NSError* error) {
        if (error && !self.cancelled) {
            [self complete:NO error:error];
            return;
        }
        if (self.settings.outputType == RecordingSettings::OutputType::Gif) {
            BOOL okay = self.gifDestination && self.gifFrameCount > 0 &&
              CGImageDestinationFinalize(self.gifDestination);
            if (self.gifDestination) {
                CFRelease(self.gifDestination);
                self.gifDestination = nullptr;
            }
            [self complete:okay error:nil];
            return;
        }
        [self.videoInput markAsFinished];
        [self.systemAudioInput markAsFinished];
        [self.microphoneInput markAsFinished];
        [self.writer finishWritingWithCompletionHandler:^{
            [self complete:self.writer.status == AVAssetWriterStatusCompleted
                      error:self.writer.error];
        }];
    };
    if (self.stream) {
        [self.stream stopCaptureWithCompletionHandler:finalizeOutput];
    } else {
        finalizeOutput(nil);
    }
}

- (void)complete:(BOOL)okay error:(NSError*)error
{
    RecordingService* target = self.owner;
    const QString path = QString::fromNSString(self.outputPath);
    if (self.cancelled || !okay) {
        [[NSFileManager defaultManager] removeItemAtPath:self.outputPath error:nil];
    }
    if (!target) {
        return;
    }
    QMetaObject::invokeMethod(target, [target, path, okay, cancelled = self.cancelled,
                                       message = QString::fromNSString(error.localizedDescription ?: @"Unable to finish recording")]() {
        if (cancelled) {
            return;
        }
        okay ? emit target->finished(path) : emit target->failed(message);
    });
}
@end

RecordingService::RecordingService(QObject* parent) : QObject(parent) {}

RecordingService::~RecordingService()
{
    cancel();
    if (m_native) {
        CFBridgingRelease(m_native);
        m_native = nullptr;
    }
}

bool RecordingService::isAvailable()
{
    return QOperatingSystemVersion::current() >=
      QOperatingSystemVersion(QOperatingSystemVersion::MacOS, 12, 3);
}

bool RecordingService::systemAudioAvailable()
{
    return QOperatingSystemVersion::current() >=
      QOperatingSystemVersion(QOperatingSystemVersion::MacOS, 13, 0);
}

bool RecordingService::requestMicrophonePermission()
{
    __block bool granted = false;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio
                            completionHandler:^(BOOL value) {
        granted = value;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore,
                            dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    return granted;
}

QList<QPair<QString, QString>> RecordingService::audioInputDevices()
{
    QList<QPair<QString, QString>> result;
    AVCaptureDeviceDiscoverySession* discovery =
      [AVCaptureDeviceDiscoverySession
        discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInMicrophone,
                                            AVCaptureDeviceTypeExternalUnknown ]
                              mediaType:AVMediaTypeAudio
                               position:AVCaptureDevicePositionUnspecified];
    for (AVCaptureDevice* device in discovery.devices) {
        result.append({ QString::fromNSString(device.localizedName),
                        QString::fromNSString(device.uniqueID) });
    }
    return result;
}

bool RecordingService::start(const QRect& globalRegion,
                             const QString& outputPath,
                             const RecordingSettings& settings)
{
    if (!isAvailable() || !globalRegion.isValid()) {
        emit failed(tr("Recording is only available on macOS 12.3 or later."));
        return false;
    }
    if (@available(macOS 12.3, *)) {
        if (m_native &&
            !((__bridge FlameshotRecordingBridge*)m_native).recording) {
            CFBridgingRelease(m_native);
            m_native = nullptr;
        }
    }
    if (m_native) {
        return false;
    }
    if (settings.captureMicrophone && !requestMicrophonePermission()) {
        emit failed(tr("Microphone permission was not granted."));
        return false;
    }
    if (@available(macOS 12.3, *)) {
        auto* bridge = [[FlameshotRecordingBridge alloc] init];
        bridge.owner = this;
        bridge.settings = settings;
        bridge.outputPath = outputPath.toNSString();
        bridge.firstPTS = kCMTimeInvalid;
        bridge.pauseOffset = kCMTimeZero;
        bridge.recording = YES;
        m_native = const_cast<void*>(CFBridgingRetain(bridge));

        [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                                    onScreenWindowsOnly:YES
                                                     completionHandler:^(SCShareableContent* content,
                                                                         NSError* error) {
            if (error || content.displays.count == 0) {
                [bridge reportFailure:error.localizedDescription ?: @"No display is available"];
                return;
            }
            const CGPoint center = CGPointMake(globalRegion.center().x(),
                                               globalRegion.center().y());
            SCDisplay* display = nil;
            for (SCDisplay* item in content.displays) {
                if (CGRectContainsPoint(item.frame, center)) {
                    display = item;
                    break;
                }
            }
            if (!display) {
                display = content.displays.firstObject;
            }
            CGRect selected = CGRectMake(globalRegion.x() - display.frame.origin.x,
                                         globalRegion.y() - display.frame.origin.y,
                                         globalRegion.width(),
                                         globalRegion.height());
            selected = CGRectIntersection(selected,
                                          CGRectMake(0, 0, display.width, display.height));
            if (CGRectIsEmpty(selected)) {
                [bridge reportFailure:@"The selected region is outside the display"];
                return;
            }
            CGFloat scale = 1.0;
            for (NSScreen* screen in NSScreen.screens) {
                NSNumber* number = screen.deviceDescription[@"NSScreenNumber"];
                if (number.unsignedIntValue == display.displayID) {
                    scale = screen.backingScaleFactor;
                    break;
                }
            }
            NSInteger width = qRound(selected.size.width * scale);
            NSInteger height = qRound(selected.size.height * scale);
            if (settings.longEdge == -50) {
                width /= 2;
                height /= 2;
            } else if (settings.longEdge == -1 && settings.customWidth > 0 &&
                       settings.customHeight > 0) {
                const double factor = qMin(settings.customWidth / double(width),
                                           settings.customHeight / double(height));
                width = qRound(width * factor);
                height = qRound(height * factor);
            } else if (settings.longEdge > 0 && qMax(width, height) > settings.longEdge) {
                const double factor = settings.longEdge / double(qMax(width, height));
                width = qRound(width * factor);
                height = qRound(height * factor);
            }
            width = qMax<NSInteger>(2, width & ~1);
            height = qMax<NSInteger>(2, height & ~1);
            bridge.outputWidth = width;
            bridge.outputHeight = height;

            SCRunningApplication* ownApp = nil;
            for (SCRunningApplication* app in content.applications) {
                if (app.processID == NSProcessInfo.processInfo.processIdentifier) {
                    ownApp = app;
                    break;
                }
            }
            NSArray* excluded = ownApp ? @[ ownApp ] : @[];
            SCContentFilter* filter =
              [[SCContentFilter alloc] initWithDisplay:display
                                  excludingApplications:excluded
                                      exceptingWindows:@[]];
            SCStreamConfiguration* config = [[SCStreamConfiguration alloc] init];
            config.sourceRect = selected;
            config.width = width;
            config.height = height;
            config.minimumFrameInterval = CMTimeMake(1, settings.frameRate);
            config.queueDepth = 5;
            config.showsCursor = settings.showCursor;
            if ([config respondsToSelector:NSSelectorFromString(@"setShowsMouseClicks:")]) {
                [config setValue:@(settings.highlightClicks)
                          forKey:@"showsMouseClicks"];
            }
            if (@available(macOS 13.0, *)) {
                config.capturesAudio = settings.outputType == RecordingSettings::OutputType::Video &&
                  settings.captureSystemAudio;
                config.sampleRate = 48000;
                config.channelCount = 2;
                config.excludesCurrentProcessAudio = YES;
            }

            if (settings.outputType == RecordingSettings::OutputType::Gif) {
                NSURL* url = [NSURL fileURLWithPath:bridge.outputPath];
                bridge.gifDestination = CGImageDestinationCreateWithURL(
                  (__bridge CFURLRef)url,
                  (__bridge CFStringRef)UTTypeGIF.identifier,
                  0,
                  nullptr);
                NSDictionary* gifProperties = @{
                    (__bridge NSString*)kCGImagePropertyGIFDictionary : @{
                        (__bridge NSString*)kCGImagePropertyGIFLoopCount :
                          @(settings.gifLoopCount)
                    }
                };
                CGImageDestinationSetProperties(
                  bridge.gifDestination,
                  (__bridge CFDictionaryRef)gifProperties);
            } else {
                [bridge configureWriter];
                if (!bridge.recording || !bridge.writer) {
                    return;
                }
                [bridge configureMicrophone];
                if (!bridge.recording) {
                    return;
                }
            }
            bridge.stream = [[SCStream alloc] initWithFilter:filter
                                               configuration:config
                                                    delegate:bridge];
            NSError* addError = nil;
            dispatch_queue_t queue = dispatch_queue_create("org.flameshot.ai.recording",
                                                            DISPATCH_QUEUE_SERIAL);
            [bridge.stream addStreamOutput:bridge
                                      type:SCStreamOutputTypeScreen
                        sampleHandlerQueue:queue
                                     error:&addError];
            if (@available(macOS 13.0, *)) {
                if (config.capturesAudio) {
                    [bridge.stream addStreamOutput:bridge
                                              type:SCStreamOutputTypeAudio
                                sampleHandlerQueue:queue
                                             error:&addError];
                }
            }
            if (addError) {
                [bridge reportFailure:addError.localizedDescription];
                return;
            }
            if (!bridge.recording) {
                return;
            }
            [bridge.stream startCaptureWithCompletionHandler:^(NSError* startError) {
                if (startError) {
                    [bridge reportFailure:startError.localizedDescription];
                }
            }];
        }];
        return true;
    }
    return false;
}

void RecordingService::pause()
{
    if (!m_native) return;
    if (@available(macOS 12.3, *)) {
        auto* bridge = (__bridge FlameshotRecordingBridge*)m_native;
        if (!bridge.recording || bridge.paused) return;
        bridge.paused = YES;
        bridge.pauseStart = CMClockGetTime(CMClockGetHostTimeClock());
        emit pausedChanged(true);
    }
}

void RecordingService::resume()
{
    if (!m_native) return;
    if (@available(macOS 12.3, *)) {
        auto* bridge = (__bridge FlameshotRecordingBridge*)m_native;
        if (!bridge.recording || !bridge.paused) return;
        bridge.pauseOffset = CMTimeAdd(
          bridge.pauseOffset,
          CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()), bridge.pauseStart));
        bridge.paused = NO;
        emit pausedChanged(false);
    }
}

void RecordingService::stop()
{
    if (@available(macOS 12.3, *)) {
        if (m_native) {
            [(__bridge FlameshotRecordingBridge*)m_native finish];
        }
    }
}

void RecordingService::cancel()
{
    if (@available(macOS 12.3, *)) {
        if (m_native) {
            auto* bridge = (__bridge FlameshotRecordingBridge*)m_native;
            bridge.cancelled = YES;
            [bridge finish];
        }
    }
}

bool RecordingService::isRecording() const
{
    if (@available(macOS 12.3, *)) {
        if (m_native) {
            return ((__bridge FlameshotRecordingBridge*)m_native).recording;
        }
    }
    return false;
}

bool RecordingService::isPaused() const
{
    if (@available(macOS 12.3, *)) {
        if (m_native) {
            return ((__bridge FlameshotRecordingBridge*)m_native).paused;
        }
    }
    return false;
}
