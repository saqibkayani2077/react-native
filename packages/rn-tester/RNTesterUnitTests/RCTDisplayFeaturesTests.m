/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import <React/RCTDisplayFeatures.h>

// The iPhone Duo inner display as measured on the simulator: 951x669pt with a
// 40pt fold division through the centre, and an occlusion region where an
// active camera sits. The same fixtures are used by flutter/flutter#193025,
// whose mapping rules this implementation follows.
static const CGFloat kInnerWidth = 951;
static const CGFloat kInnerHeight = 669;

static RCTReservedRegionInfo *Division(CGFloat width, BOOL active)
{
  return [[RCTReservedRegionInfo alloc] initWithFrame:CGRectMake((kInnerWidth - width) / 2, 0, width, kInnerHeight)
                                             division:YES
                                               active:active];
}

static RCTReservedRegionInfo *Occlusion(BOOL active)
{
  return [[RCTReservedRegionInfo alloc] initWithFrame:CGRectMake(867, 0, 84, 120) division:NO active:active];
}

@interface RCTDisplayFeaturesTests : XCTestCase
@end

@implementation RCTDisplayFeaturesTests

- (void)testPartiallyOpenDivisionBecomesHalfOpenedFold
{
  NSArray<NSDictionary *> *features =
      RCTDisplayFeaturesFromRegions(RCTHingeStatusPartiallyOpen, @[ Division(40, YES) ]);

  XCTAssertEqual(features.count, 1u);
  XCTAssertEqualObjects(features[0][@"type"], @"fold");
  XCTAssertEqualObjects(features[0][@"state"], @"postureHalfOpened");
  NSDictionary *bounds = features[0][@"bounds"];
  XCTAssertEqualWithAccuracy([bounds[@"x"] doubleValue], 455.5, 0.01);
  XCTAssertEqualWithAccuracy([bounds[@"y"] doubleValue], 0, 0.01);
  XCTAssertEqualWithAccuracy([bounds[@"width"] doubleValue], 40, 0.01);
  XCTAssertEqualWithAccuracy([bounds[@"height"] doubleValue], kInnerHeight, 0.01);
}

- (void)testFullyOpenReportsNoFoldEvenIfTheDivisionStillReadsActive
{
  // isActive lags the hinge: in the update that reports fully open the
  // division can still read active, and nothing follows to correct it. A 40pt
  // fold would split layouts on a device lying flat.
  NSArray<NSDictionary *> *features = RCTDisplayFeaturesFromRegions(RCTHingeStatusFullyOpen, @[ Division(40, YES) ]);

  XCTAssertEqual(features.count, 0u);
}

- (void)testFullyOpenStillReportsAnActiveOcclusion
{
  NSArray<NSDictionary *> *features =
      RCTDisplayFeaturesFromRegions(RCTHingeStatusFullyOpen, @[ Division(40, YES), Occlusion(YES) ]);

  XCTAssertEqual(features.count, 1u);
  XCTAssertEqualObjects(features[0][@"type"], @"cutout");
}

- (void)testClosedReportsNothing
{
  // The app is on the cover display, which has no fold, and there is no
  // posture to describe "closed" with.
  NSArray<NSDictionary *> *features =
      RCTDisplayFeaturesFromRegions(RCTHingeStatusClosed, @[ Division(40, YES), Occlusion(YES) ]);

  XCTAssertEqual(features.count, 0u);
}

- (void)testInactiveDivisionIsDropped
{
  NSArray<NSDictionary *> *features =
      RCTDisplayFeaturesFromRegions(RCTHingeStatusPartiallyOpen, @[ Division(40, NO) ]);

  XCTAssertEqual(features.count, 0u);
}

- (void)testZeroWidthDivisionIsDropped
{
  NSArray<NSDictionary *> *features = RCTDisplayFeaturesFromRegions(RCTHingeStatusPartiallyOpen, @[ Division(0, YES) ]);

  XCTAssertEqual(features.count, 0u);
}

- (void)testOcclusionBecomesCutoutWithUnknownState
{
  NSArray<NSDictionary *> *features = RCTDisplayFeaturesFromRegions(RCTHingeStatusPartiallyOpen, @[ Occlusion(YES) ]);

  XCTAssertEqual(features.count, 1u);
  XCTAssertEqualObjects(features[0][@"type"], @"cutout");
  XCTAssertEqualObjects(features[0][@"state"], @"unknown");
}

- (void)testInactiveOcclusionIsDropped
{
  NSArray<NSDictionary *> *features = RCTDisplayFeaturesFromRegions(RCTHingeStatusFullyOpen, @[ Occlusion(NO) ]);

  XCTAssertEqual(features.count, 0u);
}

- (void)testMixedRegionsKeepOrder
{
  NSArray<NSDictionary *> *features = RCTDisplayFeaturesFromRegions(
      RCTHingeStatusPartiallyOpen, @[ Division(40, YES), Occlusion(YES), Division(0, YES) ]);

  XCTAssertEqual(features.count, 2u);
  XCTAssertEqualObjects(features[0][@"type"], @"fold");
  XCTAssertEqualObjects(features[1][@"type"], @"cutout");
}

- (void)testUnknownStatusReportsNoFoldButKeepsOcclusions
{
  // Unknown covers devices without a hinge and the moments before the first
  // hinge update; neither should ever report a fold, but an in-use camera is
  // still real.
  NSArray<NSDictionary *> *features =
      RCTDisplayFeaturesFromRegions(RCTHingeStatusUnknown, @[ Division(40, YES), Occlusion(YES) ]);

  XCTAssertEqual(features.count, 1u);
  XCTAssertEqualObjects(features[0][@"type"], @"cutout");
}

- (void)testBoundsAreReportedInPoints
{
  // Sanity-check a non-centred region round-trips untouched.
  RCTReservedRegionInfo *region = [[RCTReservedRegionInfo alloc] initWithFrame:CGRectMake(10, 20, 30, 40)
                                                                      division:NO
                                                                        active:YES];
  NSArray<NSDictionary *> *features = RCTDisplayFeaturesFromRegions(RCTHingeStatusFullyOpen, @[ region ]);

  NSDictionary *bounds = features[0][@"bounds"];
  XCTAssertEqualObjects(bounds, (@{@"x" : @10, @"y" : @20, @"width" : @30, @"height" : @40}));
}

@end
