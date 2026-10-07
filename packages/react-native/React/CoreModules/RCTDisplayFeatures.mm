/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTDisplayFeatures.h"

#import <React/RCTAssert.h>

@implementation RCTReservedRegionInfo

- (instancetype)initWithFrame:(CGRect)frame division:(BOOL)division active:(BOOL)active
{
  if (self = [super init]) {
    _frame = frame;
    _division = division;
    _active = active;
  }
  return self;
}

@end

NSArray<NSDictionary *> *RCTDisplayFeaturesFromRegions(
    RCTHingeStatus status,
    NSArray<RCTReservedRegionInfo *> *regions)
{
  // With the device closed the app is on the cover display, which has no
  // fold, and there is no posture to describe "closed" anyway.
  if (status == RCTHingeStatusClosed) {
    return @[];
  }

  NSMutableArray<NSDictionary *> *features = [NSMutableArray new];
  for (RCTReservedRegionInfo *region in regions) {
    if (!region.isActive) {
      continue;
    }
    if (CGRectGetWidth(region.frame) <= 0 || CGRectGetHeight(region.frame) <= 0) {
      continue;
    }

    NSString *type;
    NSString *state;
    if (region.isDivision) {
      // The hinge status is immediate; isActive lags it and can still read
      // true in the very update that reports fully open, with nothing
      // following to correct it. The posture therefore decides whether there
      // is a fold. Without this, a 40pt fold would split layouts on a device
      // lying flat.
      if (status != RCTHingeStatusPartiallyOpen) {
        continue;
      }
      // The inner display is one continuous panel; there is no physical gap,
      // so this is a fold rather than a hinge.
      type = @"fold";
      state = @"postureHalfOpened";
    } else {
      type = @"cutout";
      state = @"unknown";
    }

    [features addObject:@{
      @"type" : type,
      @"state" : state,
      @"bounds" : @{
        @"x" : @(CGRectGetMinX(region.frame)),
        @"y" : @(CGRectGetMinY(region.frame)),
        @"width" : @(CGRectGetWidth(region.frame)),
        @"height" : @(CGRectGetHeight(region.frame)),
      },
    }];
  }
  return features;
}

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST && defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && \
    __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100

// The hinge and reserved-region APIs are declared by the iOS 27.1 SDK. This
// implementation is only compiled when building against that SDK or newer;
// the stub below stands in otherwise so callers need no compile-time guard.

@interface RCTDisplayFeaturesMonitor ()
- (void)_readAndReport;
- (void)_setHingeStatus:(RCTHingeStatus)status;
@end

/// Empty, non-interactive and full-window: it draws nothing and receives no
/// touches, but UIKit lays it out, and the reserved-region read made during
/// that layout is what UIKit tracks to run layout again when a region
/// changes. See the header for why the read has to happen here.
API_AVAILABLE(ios(27.1))
@interface RCTDisplayFeaturesObserverView : UIView
@property (nonatomic, weak) RCTDisplayFeaturesMonitor *monitor;
@end

@implementation RCTDisplayFeaturesObserverView

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self.monitor _readAndReport];
}

@end

@implementation RCTDisplayFeaturesMonitor {
  __weak UIWindow *_window;
  RCTDisplayFeaturesObserverView *_observerView;
  UIHingeInteraction *_interaction;
  RCTDisplayFeaturesUpdateBlock _onUpdate;
  RCTHingeStatus _hingeStatus;
}

- (nullable instancetype)initWithWindow:(nullable UIWindow *)window
                               onUpdate:(RCTDisplayFeaturesUpdateBlock)onUpdate
{
  if (window == nil) {
    return nil;
  }
  if (self = [super init]) {
    _window = window;
    _onUpdate = [onUpdate copy];
    _hingeStatus = RCTHingeStatusUnknown;

    _observerView = [[RCTDisplayFeaturesObserverView alloc] initWithFrame:window.bounds];
    _observerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _observerView.userInteractionEnabled = NO;
    _observerView.monitor = self;
    [window addSubview:_observerView];

    __weak RCTDisplayFeaturesMonitor *weakSelf = self;
    _interaction = [[UIHingeInteraction alloc]
        initWithUpdateHandler:^(UIHingeInteraction *interaction, UIHingeInteractionUpdate *update) {
          RCTDisplayFeaturesMonitor *strongSelf = weakSelf;
          if (strongSelf == nil) {
            return;
          }
          // A nil hinge means this device has none, or the interaction left a
          // hierarchy that provides hinge updates.
          UIHinge *hinge = update.hinge;
          [strongSelf _setHingeStatus:hinge ? (RCTHingeStatus)hinge.status : RCTHingeStatusUnknown];
          [strongSelf refresh];
        }];
    [_observerView addInteraction:_interaction];
  }
  return self;
}

- (nullable UIWindow *)window
{
  return _window;
}

- (void)_setHingeStatus:(RCTHingeStatus)status
{
  _hingeStatus = status;
}

- (void)refresh
{
  [_observerView setNeedsLayout];
}

- (void)_readAndReport
{
  RCTAssertMainQueue();
  UIView *view = _observerView;
  if (view == nil) {
    return;
  }

  NSMutableArray<RCTReservedRegionInfo *> *regions = [NSMutableArray new];
  // The fold is inactive while the device is flat, so it is requested with
  // IncludeInactive; the mapping drops inactive regions itself, and this
  // keeps the query — and so the dependency UIKit tracks — identical across
  // postures.
  for (UIViewReservedRegion *region in
       [view reservedRegionsOfKind:[UIViewReservedRegionKind divisionRegionKind]
                           options:UIViewReservedRegionQueryOptionsIncludeInactive]) {
    [regions addObject:[[RCTReservedRegionInfo alloc] initWithFrame:region.frame
                                                           division:YES
                                                             active:region.isActive]];
  }
  // An occlusion is only active while that camera is in use.
  for (UIViewReservedRegion *region in
       [view reservedRegionsOfKind:[UIViewReservedRegionKind occlusionRegionKind]
                           options:UIViewReservedRegionQueryOptionsNone]) {
    [regions addObject:[[RCTReservedRegionInfo alloc] initWithFrame:region.frame
                                                           division:NO
                                                             active:region.isActive]];
  }

  // Held locally so that a handler which ends up invalidating this monitor
  // cannot release the block while it is running.
  RCTDisplayFeaturesUpdateBlock onUpdate = _onUpdate;
  if (onUpdate) {
    onUpdate(RCTDisplayFeaturesFromRegions(_hingeStatus, regions));
  }
}

- (void)invalidate
{
  if (_interaction) {
    [_observerView removeInteraction:_interaction];
    _interaction = nil;
  }
  _observerView.monitor = nil;
  [_observerView removeFromSuperview];
  _observerView = nil;
  _onUpdate = nil;
}

- (void)dealloc
{
  // The owner is expected to call invalidate. This covers the case where it
  // does not, so the interaction and the observer view never outlive the
  // monitor inside a live window.
  if (_interaction) {
    [_observerView removeInteraction:_interaction];
  }
  [_observerView removeFromSuperview];
}

@end

#else // Non-iOS target, or built against an SDK without the hinge APIs.

// Nothing to observe: returning nil from init lets RCTDeviceInfo keep a
// single code path behind one `@available` check.

@implementation RCTDisplayFeaturesMonitor

- (nullable instancetype)initWithWindow:(nullable UIWindow *)window
                               onUpdate:(RCTDisplayFeaturesUpdateBlock)onUpdate
{
  return nil;
}

- (nullable UIWindow *)window
{
  return nil;
}

- (void)refresh
{
}

- (void)invalidate
{
}

@end

#endif // __IPHONE_OS_VERSION_MAX_ALLOWED
