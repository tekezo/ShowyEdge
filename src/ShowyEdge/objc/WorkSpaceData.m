@import Carbon;
#import "WorkSpaceData.h"
#import "NotificationKeys.h"
#import "weakify.h"

@interface WorkSpaceData ()

@property(copy, readwrite) NSString* currentInputSourceID;
@property(copy, readwrite) NSString* currentInputModeID;
@property(copy, readwrite) NSSet* menubarOrigins;

@end

@implementation WorkSpaceData

- (void)observer_kTISNotifySelectedKeyboardInputSourceChanged:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
    TISInputSourceRef ref = TISCopyCurrentKeyboardInputSource();
    if (ref) {
      NSString* currentInputSourceID = (__bridge NSString*)(TISGetInputSourceProperty(ref, kTISPropertyInputSourceID));
      NSString* currentInputModeID = (__bridge NSString*)(TISGetInputSourceProperty(ref, kTISPropertyInputModeID));

      if (currentInputSourceID.length == 0) {
        currentInputSourceID = @"unknown";
      }
      if (currentInputModeID.length == 0) {
        currentInputModeID = @"";
      }

      self.currentInputSourceID = currentInputSourceID;
      self.currentInputModeID = currentInputModeID;

      [NSNotificationCenter.defaultCenter postNotificationName:kCurrentInputSourceIDChangedNotification object:nil];

      CFRelease(ref);
    }
  });
}

- (instancetype)init {
  self = [super init];

  if (self) {
    self.currentInputSourceID = @"";
    self.currentInputModeID = @"";
    self.menubarOrigins = NSSet.new;

    // In Mac OS X 10.7, NSDistributedNotificationCenter is suspended after calling [NSAlert runModal].
    // So, we need to set suspendedDeliveryBehavior to NSNotificationSuspensionBehaviorDeliverImmediately.
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(observer_kTISNotifySelectedKeyboardInputSourceChanged:)
                                                          name:(NSString*)(kTISNotifySelectedKeyboardInputSourceChanged)
                                                          object:nil
                                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    @weakify(self);
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification
                                                                object:nil
                                                                 queue:NSOperationQueue.mainQueue
                                                            usingBlock:^(NSNotification* note) {
                                                              @strongify(self);
                                                              if (!self) return;

                                                              [self updateMenubarOrigins];
                                                            }];
  }

  return self;
}

- (void)setup {
  [self observer_kTISNotifySelectedKeyboardInputSourceChanged:nil];
  [self updateMenubarOrigins];
}

- (void)dealloc {
  [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
}

- (void)updateMenubarOrigins {
  NSArray* windows = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
  NSMutableSet* menubarOrigins = NSMutableSet.new;

  // We detect full screen spaces by checking if there's a menubar in the window list.
  // If not, we assume it's in fullscreen mode.
  for (NSDictionary* d in windows) {
    if ([d[@"kCGWindowOwnerName"] isEqualToString:@"Window Server"] &&
        [d[@"kCGWindowName"] isEqualToString:@"Menubar"]) {
      NSDictionary* bounds = d[@"kCGWindowBounds"];
      if (bounds) {
        NSNumber* x = bounds[@"X"];
        NSNumber* y = bounds[@"Y"];
        [menubarOrigins addObject:@{
          @"x" : x,
          @"y" : y,
        }];
      }
    }
  }

  if ([self.menubarOrigins isEqualToSet:menubarOrigins]) {
    return;
  }

  self.menubarOrigins = menubarOrigins;

  [NSNotificationCenter.defaultCenter postNotificationName:kFullScreenModeChangedNotification object:nil];
}

@end
