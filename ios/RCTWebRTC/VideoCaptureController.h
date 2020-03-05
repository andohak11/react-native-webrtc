
#import <Foundation/Foundation.h>
#import <WebRTC/RTCCameraVideoCapturer.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoCaptureController : NSObject

-(instancetype)initWithCapturer:(RTCCameraVideoCapturer *)capturer
                 andConstraints:(NSDictionary *)constraints;
-(void)startCapture;
-(void)stopCapture;
-(void)switchCamera;

@property (nonatomic, strong) AVCaptureDeviceFormat *selectedFormat;

@end
