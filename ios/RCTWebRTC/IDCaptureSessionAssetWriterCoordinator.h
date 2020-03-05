#import "IDCaptureSessionCoordinator.h"

@protocol IDCaptureSessionAssetWriterCoordinatorDelegate;

@interface IDCaptureSessionAssetWriterCoordinator : IDCaptureSessionCoordinator

- (void)addVideoDataOutputExplicit:(AVCaptureVideoDataOutput *)newVideoOutput;


@end
