/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict
 * @format
 */

import type {TurboModule} from '../../../../Libraries/TurboModule/RCTExport';

import * as TurboModuleRegistry from '../../../../Libraries/TurboModule/TurboModuleRegistry';

export type DisplayMetricsAndroid = {
  width: number,
  height: number,
  scale: number,
  fontScale: number,
  densityDpi: number,
};

export type DisplayMetrics = {
  width: number,
  height: number,
  scale: number,
  fontScale: number,
};

// A region of the display that content should avoid, such as a fold, a hinge
// or a front-facing camera. Modeled after the reserved regions of iPhone Duo
// (see the "Designing for iPhone Duo" Human Interface Guidelines and Apple
// Tech Talk 111463, "Strike a pose with adaptive layouts on iPhone Duo") so
// that a foldable/dual-display Android device can report through the same
// shape.
//
// 'fold': a flexible region of one continuous display with no physical gap
// (iPhone Duo's inner display). 'hinge': a physical gap between two separate
// display panels. 'cutout': an occlusion such as an in-use camera.
export type DisplayFeatureType = 'fold' | 'hinge' | 'cutout';

// The posture of a 'fold' or 'hinge' DisplayFeature. Always 'unknown' for
// 'cutout'.
export type DisplayFeatureState =
  | 'unknown'
  | 'postureFlat'
  | 'postureHalfOpened';

export type DisplayFeatureRect = {
  readonly x: number,
  readonly y: number,
  readonly width: number,
  readonly height: number,
};

export type DisplayFeature = {
  readonly type: DisplayFeatureType,
  readonly state: DisplayFeatureState,
  // In the same coordinate space as the 'window' DisplayMetrics, in points.
  readonly bounds: DisplayFeatureRect,
};

export type DimensionsPayload = {
  window?: DisplayMetrics,
  screen?: DisplayMetrics,
  windowPhysicalPixels?: DisplayMetricsAndroid,
  screenPhysicalPixels?: DisplayMetricsAndroid,
  // Populated on iOS 27.1+ devices with reserved display regions (iPhone
  // Duo); empty elsewhere. See RCTDisplayFeatures.h for the mapping rules.
  displayFeatures?: ReadonlyArray<DisplayFeature>,
};

export type DeviceInfoConstants = {
  readonly Dimensions: DimensionsPayload,
  readonly isEdgeToEdge?: boolean,
  readonly isIPhoneX_deprecated?: boolean,
};

export interface Spec extends TurboModule {
  readonly getConstants: () => DeviceInfoConstants;
}

const NativeModule: Spec = TurboModuleRegistry.getEnforcing<Spec>('DeviceInfo');

export default NativeModule;
