//
//  StreamViewMac.h
//  Moonlight for macOS
//
//  Created by Michael Kenny on 27/12/17.
//  Copyright © 2017 Moonlight Stream. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StreamViewController.h"

@interface StreamViewMac : NSView
@property (nonatomic, strong) NSString *statusText;
@property (nonatomic, strong) NSString *appName;
// Text shown in a translucent box in the top-left corner of the stream. nil hides it.
@property (nonatomic, copy) NSString *overlayText;
@property (nonatomic, weak) id<KeyboardNotifiableDelegate> keyboardNotifiable;

@end
