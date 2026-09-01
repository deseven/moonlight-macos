//
//  StreamViewController.h
//  Moonlight for macOS
//
//  Created by Michael Kenny on 25/12/17.
//  Copyright © 2017 Moonlight Stream. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TemporaryApp.h"
#import "AppsViewControllerDelegate.h"

@protocol KeyboardNotifiableDelegate <NSObject>

- (BOOL)onKeyboardEquivalent:(NSEvent *)event;

@end

struct Resolution {
   int width;
   int height;
};

@interface StreamViewController : NSViewController
@property (nonatomic, strong) TemporaryApp *app;
@property (nonatomic, weak) id<AppsViewControllerDelegate> delegate;

// Returns the currently active stream view controller, or nil if no local
// stream is running. Used to avoid starting a second stream (which would
// clobber moonlight-common's global connection state and crash the app).
+ (StreamViewController *)activeStreamViewController;

// Brings the window hosting this stream back into focus.
- (void)focusStreamWindow;

// Stops the local stream (terminating the connection) and closes the stream
// window. The completion block is invoked (on the main queue) once the
// connection has fully terminated, or immediately if there's no connection.
// Used when switching to a different app so the new stream can't start before
// the old one is fully torn down.
- (void)stopStreamAndCloseWithCompletion:(void (^)(void))completion;

+ (struct Resolution)getResolution;
@end
