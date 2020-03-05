#import <Foundation/Foundation.h>

@interface IDFileManager : NSObject

- (NSURL *) tempFileURL;
- (void) removeFile:(NSURL *)outputFileURL;
- (void) copyFileToDocuments:(NSURL *)fileURL;
- (void) copyFileToCameraRoll:(NSURL *)fileURL;
@end
