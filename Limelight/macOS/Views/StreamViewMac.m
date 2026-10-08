//
//  StreamViewMac.m
//  Moonlight for macOS
//
//  Created by Michael Kenny on 27/12/17.
//  Copyright © 2017 Moonlight Stream. All rights reserved.
//

#import "StreamViewMac.h"

static const CGFloat kOverlayMargin = 8;
static const CGFloat kOverlayPadding = 6;

// Purely visual; lets mouse events fall through to the stream view.
@interface StreamOverlayContainerView : NSView
@end

@implementation StreamOverlayContainerView
- (NSView *)hitTest:(NSPoint)point {
    return nil;
}
@end

@interface StreamViewMac ()
@property (nonatomic, strong) NSProgressIndicator *spinner;
@property (nonatomic, strong) StreamOverlayContainerView *overlayContainer;
@property (nonatomic, strong) NSTextField *overlayLabel;

@end

@implementation StreamViewMac

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.spinner = [[NSProgressIndicator alloc] init];
        self.spinner.style = NSProgressIndicatorStyleSpinning;
        [self.spinner startAnimation:self];
        [self addSubview:self.spinner];
        self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
        [self.spinner.widthAnchor constraintEqualToConstant:32].active = YES;
        [self.spinner.heightAnchor constraintEqualToConstant:32].active = YES;
    }
    return self;
}

- (void)setStatusText:(NSString *)statusText {
    if (statusText == nil) {
        [self.spinner stopAnimation:self];
        self.spinner.hidden = YES;
        self.window.title = self.appName;
    } else {
        self.window.title = [[self.appName stringByAppendingString:@" - "] stringByAppendingString:statusText];
    }
}

- (void)setOverlayText:(NSString *)overlayText {
    _overlayText = [overlayText copy];
    
    if (overlayText == nil) {
        self.overlayContainer.hidden = YES;
        return;
    }
    
    if (self.overlayContainer == nil) {
        self.overlayContainer = [[StreamOverlayContainerView alloc] init];
        self.overlayContainer.wantsLayer = YES;
        self.overlayContainer.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:0.5].CGColor;
        self.overlayContainer.layer.cornerRadius = 6;
        // Keep pinned to the top-left corner as the window resizes
        self.overlayContainer.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
        
        self.overlayLabel = [NSTextField labelWithString:@""];
        self.overlayLabel.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
        self.overlayLabel.textColor = [NSColor colorWithWhite:0.85 alpha:1];
        self.overlayLabel.usesSingleLineMode = NO;
        self.overlayLabel.maximumNumberOfLines = 0;
        [self.overlayContainer addSubview:self.overlayLabel];
        
        [self addSubview:self.overlayContainer];
    }
    
    self.overlayLabel.stringValue = overlayText;
    [self.overlayLabel sizeToFit];
    NSSize labelSize = self.overlayLabel.frame.size;
    self.overlayLabel.frame = NSMakeRect(kOverlayPadding, kOverlayPadding, labelSize.width, labelSize.height);
    
    NSSize containerSize = NSMakeSize(labelSize.width + 2 * kOverlayPadding, labelSize.height + 2 * kOverlayPadding);
    self.overlayContainer.frame = NSMakeRect(kOverlayMargin,
                                             NSHeight(self.bounds) - kOverlayMargin - containerSize.height,
                                             containerSize.width,
                                             containerSize.height);
    self.overlayContainer.hidden = NO;
}

- (void)didAddSubview:(NSView *)subview {
    [super didAddSubview:subview];
    
    // The video renderer re-adds its layer view when it recovers from decoder
    // errors, which would otherwise cover the overlay.
    if (self.overlayContainer != nil && subview != self.overlayContainer) {
        [self addSubview:self.overlayContainer positioned:NSWindowAbove relativeTo:nil];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [[NSColor blackColor] setFill];
    NSRectFill(dirtyRect);
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    return [self.keyboardNotifiable onKeyboardEquivalent:event];
}

@end
