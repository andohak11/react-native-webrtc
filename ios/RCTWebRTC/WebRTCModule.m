//
//  WebRTCModule.m
//
//  Created by one on 2015/9/24.
//  Copyright © 2015 One. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTUtils.h>

#import "WebRTCModule.h"
#import "WebRTCModule+RTCPeerConnection.h"
#import <AVFoundation/AVFoundation.h>

@interface WebRTCModule ()

@property(nonatomic, strong) dispatch_queue_t workerQueue;

@end

@implementation WebRTCModule

@synthesize bridge = _bridge;

bool hasAudioListeners;

AVAudioRecorder *recorder;

AVCaptureSession *captureSession;
AVCaptureAudioDataOutput *audioDataOutput;

NSTimer *levelTimer;

RCTResponseSenderBlock _audioLevelSuccessCallback;
RCTResponseSenderBlock _audioLevelErrorCallback;

float prevPeak = 0.0;
float prevAvg = 0.0;
int prevCnt = 0;


+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (void)dealloc
{
  [_localTracks removeAllObjects];
  _localTracks = nil;
  [_localStreams removeAllObjects];
  _localStreams = nil;

  for (NSNumber *peerConnectionId in _peerConnections) {
    RTCPeerConnection *peerConnection = _peerConnections[peerConnectionId];
    peerConnection.delegate = nil;
    [peerConnection close];
  }
  [_peerConnections removeAllObjects];

  _peerConnectionFactory = nil;
    
    recorder = nil;
}

- (instancetype)init
{
    return [self initWithEncoderFactory:nil decoderFactory:nil];
}

- (instancetype)initWithEncoderFactory:(nullable id<RTCVideoEncoderFactory>)encoderFactory
                        decoderFactory:(nullable id<RTCVideoDecoderFactory>)decoderFactory
{
  self = [super init];
  if (self) {
    if (encoderFactory == nil) {
      encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
    }
    if (decoderFactory == nil) {
      decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
    }
    _peerConnectionFactory
      = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory
                                                  decoderFactory:decoderFactory];

    _peerConnections = [NSMutableDictionary new];
    _localStreams = [NSMutableDictionary new];
    _localTracks = [NSMutableDictionary new];

    dispatch_queue_attr_t attributes =
    dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                            QOS_CLASS_USER_INITIATED, -1);
    _workerQueue = dispatch_queue_create("WebRTCModule.queue", attributes);
  }
  return self;
}

- (RTCMediaStream*)streamForReactTag:(NSString*)reactTag
{
  RTCMediaStream *stream = _localStreams[reactTag];
  if (!stream) {
    for (NSNumber *peerConnectionId in _peerConnections) {
      RTCPeerConnection *peerConnection = _peerConnections[peerConnectionId];
      stream = peerConnection.remoteStreams[reactTag];
      if (stream) {
        break;
      }
    }
  }
  return stream;
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
  return _workerQueue;
}


#pragma mark - audio level

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"audioLevelUpdated"];
}

- (void) receiveNotification:(NSNotification *) notification
{
    //NSLog(@"WebRTCModule: AUDIOLEVEL: notification! %@", notification);
    
    if ([[notification name] isEqualToString:AVCaptureSessionWasInterruptedNotification])
        NSLog (@"WebRTCModule: AUDIOLEVEL: AVCaptureSessionWasInterruptedNotification...");
}

- (BOOL) setupAudioLevelCaptureSession {
    
    NSLog(@"WebRTCModule: AUDIOLEVEL: setupAudioLevelCaptureSession...");

    
    NSError* error = nil;
    
    prevPeak = 0.0;
    prevAvg = 0.0;
    prevCnt = 0;
    
    captureSession = [AVCaptureSession new];
    
    AVCaptureDeviceInput *micDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    
    if ([captureSession canAddInput:micDeviceInput]) {
        [captureSession addInput:micDeviceInput];
    } else {
        NSLog(@"WebRTCModule: AUDIOLEVEL: Could not addInput to Capture Session!");
        //errorCallback(@[ @"getAudioLevelError", @"Could not addInput to Capture Session!" ]);
        return NO;
    }

    audioDataOutput = [AVCaptureAudioDataOutput new];
    
    if (!audioDataOutput) {
        NSLog(@"WebRTCModule: AUDIOLEVEL: Could not create AVCaptureAudioDataOutput!");
        //errorCallback(@[ @"getAudioLevelError", @"Could not create AVCaptureAudioDataOutput!" ]);
        return NO;
    }
    
    if ([captureSession canAddOutput:audioDataOutput]) {
        [captureSession addOutput:audioDataOutput];
    } else {
        NSLog(@"WebRTCModule: AUDIOLEVEL: Could not addOutput to Capture Session!");
        //errorCallback(@[ @"getAudioLevelError", @"Could not addOutput to Capture Session!" ]);
        return NO;
    }
    
    [captureSession startRunning];
    
    if (levelTimer){
        [levelTimer invalidate];
        levelTimer = nil;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector: @selector(levelTimerCallbackNew:) userInfo: nil repeats: YES];
    });
    
    hasAudioListeners = YES;
    NSLog(@"WebRTCModule: AUDIOLEVEL: new setup complited...");

    return YES;
    
}

RCT_EXPORT_METHOD(getAudioLevel:(RCTResponseSenderBlock)successCallback
                  errorCallback:(RCTResponseSenderBlock)errorCallback) {
    
    NSLog(@"WebRTCModule: AUDIOLEVEL: getAudioLevel...");
    
    _audioLevelSuccessCallback = successCallback;
    _audioLevelErrorCallback = errorCallback;

    if ([self setupAudioLevelCaptureSession]){
        _audioLevelSuccessCallback(@[ @"getAudioLevelSuccess", @"" ]);
    } else {
        errorCallback(@[ @"getAudioLevelError", @"See console for details.." ]);
    }

    
    return;
    
//// old version
//
//    // record audio to /dev/null
//    NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];
//
//    // some settings
//    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
//                              [NSNumber numberWithFloat: 44100.0],                 AVSampleRateKey,
//                              [NSNumber numberWithInt: kAudioFormatLinearPCM], AVFormatIDKey,
//                              [NSNumber numberWithInt: 1],                         AVNumberOfChannelsKey,
//                              [NSNumber numberWithInt: AVAudioQualityMax],         AVEncoderAudioQualityKey,
//                              nil];
//
//    BOOL success = [[AVAudioSession sharedInstance]
//                    setCategory:AVAudioSessionCategoryRecord
//                    error:&error];
//
//    if (!success && error) {
//        NSLog(@"WebRTCModule: AUDIOLEVEL: error %@",error);
//        errorCallback(@[ @"getAudioLevelError", error.localizedDescription ]);
//        return;
//    }
//
//    // create a AVAudioRecorder
//    recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
//
//
//    if (recorder) {
//        [recorder prepareToRecord];
//        [recorder setMeteringEnabled:YES];
//        [recorder record];
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector: @selector(levelTimerCallback:) userInfo: nil repeats: YES];
//        });
//
//        _audioLevelSuccessCallback(@[ @"getAudioLevelSuccess", @"" ]);
//        hasAudioListeners = YES;
//
//
//
//        NSLog(@"WebRTCModule: AUDIOLEVEL: setup complited...");
//    } else {
//        NSLog(@"WebRTCModule: AUDIOLEVEL: Error in initialize Recorder: %@", [error description]);
//        errorCallback(@[ @"getAudioLevelError", error.localizedDescription ]);
//    }
    
}

- (void)levelTimerCallbackNew:(NSTimer *)timer {
    
    NSLog(@"WebRTCModule: AUDIOLEVEL: levelTimerCallbackNew...");
    
    if (audioDataOutput==nil) return;
    
    if (hasAudioListeners){
        if(!captureSession.isRunning){

            NSLog(@"WebRTCModule: AUDIOLEVEL: captureSession is not running but hasAudioListeners...");
            
            if (captureSession.isInterrupted){
                NSLog(@"WebRTCModule: AUDIOLEVEL: isInterrupted...");
            }
            
            [captureSession startRunning];
        }
    }
    
    NSArray *connections = audioDataOutput.connections;
    if ([connections count] > 0) {
        // There should be only one connection to an AVCaptureAudioDataOutput.
        AVCaptureConnection *connection = [connections objectAtIndex:0];
        
        NSArray *audioChannels = connection.audioChannels;
        
        for (AVCaptureAudioChannel *channel in audioChannels) {
            
            
            
            float avg = channel.averagePowerLevel;
            float peak = channel.peakHoldLevel;
            
            if ((peak == prevPeak) && (avg == prevAvg)){
                prevCnt++;
            } else {
                prevCnt = 0;
            }
            
            if (prevCnt>3){
            
                if (hasAudioListeners){
                
                    NSLog(@"WebRTCModule: AUDIOLEVEL: restarting session because 3 times and hasAudioListeners");
                
                    [self clearAudioLevelSession];
                    [self setupAudioLevelCaptureSession];
                }
            }
            
            NSLog(@"WebRTCModule: AUDIOLEVEL: levelTimerCallback: peak:%f avg: %f", peak, avg);
            
            if (hasAudioListeners){
                [self sendEventWithName:@"audioLevelUpdated" body:@{
                                                                    @"peak": [NSNumber numberWithFloat:peak],
                                                                    @"average":[NSNumber numberWithFloat:avg]
                                                                    }];
            }
            
            prevPeak = peak;
            prevAvg = avg;
            
            break;
        }
    }

    
}


- (void)levelTimerCallback:(NSTimer *)timer {
    [recorder updateMeters];
    
    float peakDecebels =  [recorder peakPowerForChannel:0];
    //NSLog(@"peak: %f", peakDecebels);
    float averagePower = [recorder averagePowerForChannel:0];
    //NSLog(@"averagePower: %f", avaeragePower);
    
    if (hasAudioListeners){
        [self sendEventWithName:@"audioLevelUpdated" body:@{
                                                        @"peak": [NSNumber numberWithFloat:peakDecebels],
                                                        @"average":[NSNumber numberWithFloat:averagePower]
                                                        }];
        //NSLog(@"WebRTCModule: AUDIOLEVEL: levelTimerCallback: peak:%f avg: %f", peakDecebels, averagePower);
    }
}

- (void) clearAudioLevelSession {

    NSLog(@"WebRTCModule: AUDIOLEVEL: clearAudioLevelSession...");

    if (captureSession){
        [captureSession stopRunning];
        captureSession = nil;
    }

    if (levelTimer){
        [levelTimer invalidate];
        levelTimer = nil;
        _audioLevelErrorCallback = nil;
        _audioLevelSuccessCallback = nil;
    }

    if (recorder){
        [recorder stop];
        recorder = nil;
    }

    
}

RCT_EXPORT_METHOD(stopAudioLevel:(RCTResponseSenderBlock)successCallback
                  errorCallback:(RCTResponseSenderBlock)errorCallback) {
    
    [self clearAudioLevelSession];
    
    hasAudioListeners = NO;
    
    
}

@end
