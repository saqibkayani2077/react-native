/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

#import <React/RCTDefines.h>

NS_ASSUME_NONNULL_BEGIN

/// Mirrors the raw values of `UIHingeStatus` (iOS 27.1 SDK), so the mapping
/// below can be unit-tested on toolchains whose SDK does not declare the real
/// enum.
typedef NS_ENUM(NSInteger, RCTHingeStatus) {
  RCTHingeStatusUnknown = 0,
  RCTHingeStatusClosed = 1,
  RCTHingeStatusPartiallyOpen = 2,
  RCTHingeStatusFullyOpen = 3,
};

/// A reserved region as read from `-[UIView reservedRegionsOfKind:options:]`
/// (iOS 27.1), reduced to what the mapping needs.
@interface RCTReservedRegionInfo : NSObject

/// In the observed window's coordinate space, in points — the same space as
/// the `window` DisplayMetrics that JS receives.
@property (nonatomic, readonly) CGRect frame;

/// YES for a division (the fold), NO for an occlusion (a camera).
@property (nonatomic, readonly, getter=isDivision) BOOL division;

/// A division is inactive while the device is flat. This lags the hinge; see
/// the mapping rules below for why it is never trusted on its own.
@property (nonatomic, readonly, getter=isActive) BOOL active;

- (instancetype)initWithFrame:(CGRect)frame division:(BOOL)division active:(BOOL)active;

@end

/// Converts the hinge posture and reserved regions into the `displayFeatures`
/// entries of the Dimensions payload: `{type, state, bounds: {x, y, width,
/// height}}` dictionaries, where `type` is 'fold' | 'hinge' | 'cutout' and
/// `state` is 'unknown' | 'postureFlat' | 'postureHalfOpened', matching the
/// `DisplayFeature` Flow type in NativeDeviceInfo.js.
///
/// Rules, each of which exists to keep a layout from avoiding a fold that is
/// not visible (measured on the iPhone Duo simulator; the same behaviors are
/// documented in flutter/flutter#193025, which this mapping follows):
///
/// * Nothing is reported while the device is closed: the app is on the cover
///   display, which has no fold.
/// * A division is reported only while the hinge is partially open. The hinge
///   status is immediate, but a region's `isActive` lags it — a division can
///   still read active inside the very update that reports fully open, with
///   nothing following to correct it. The posture therefore decides whether a
///   fold exists.
/// * Inactive regions are never reported.
/// * A region with a zero side is never reported.
/// * Divisions become 'fold', not 'hinge': the inner display is one
///   continuous panel with no physical gap between two separate screens.
/// * Occlusions become 'cutout' with state 'unknown'.
RCT_EXTERN NSArray<NSDictionary *> *RCTDisplayFeaturesFromRegions(
    RCTHingeStatus status,
    NSArray<RCTReservedRegionInfo *> *regions);

/// Delivers the current display features. Called on the main thread.
typedef void (^RCTDisplayFeaturesUpdateBlock)(NSArray<NSDictionary *> *features);

/// Observes the hinge and the reserved regions of a window and reports them
/// as display features whenever either changes.
///
/// The hinge APIs ship in the iOS 27.1 SDK. Built against an older SDK, or
/// for a non-iOS Apple platform, this class still exists but `init` returns
/// nil, so callers need only an `@available(iOS 27.1, *)` check.
///
/// Reserved regions lag the hinge and UIKit posts no notification for them;
/// what it does instead is track a region read made during a layout pass and
/// run layout again when that region changes (measured in
/// flutter/flutter#193025). RCTDeviceInfo has no layout callback of its own,
/// so the monitor adds an empty, non-interactive, full-window view to the
/// observed window and performs the read from that view's `layoutSubviews`;
/// hinge updates mark it as needing layout, and UIKit's tracked-read behavior
/// re-runs it when a region changes without a hinge event (for example, a
/// camera occlusion appearing).
API_AVAILABLE(ios(27.1))
@interface RCTDisplayFeaturesMonitor : NSObject

/// The window this monitor observes. Compare against `RCTKeyWindow()` to
/// decide whether the monitor must be recreated after a scene reconnect.
@property (nonatomic, readonly, weak, nullable) UIWindow *window;

/// Starts observing `window`. Returns nil when the SDK this file was built
/// against does not declare the hinge APIs, or when `window` is nil.
- (nullable instancetype)initWithWindow:(nullable UIWindow *)window
                               onUpdate:(RCTDisplayFeaturesUpdateBlock)onUpdate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Schedules a re-read of the reserved regions on the next layout pass.
- (void)refresh;

/// Stops observing, removes the observer view and releases the interaction.
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
