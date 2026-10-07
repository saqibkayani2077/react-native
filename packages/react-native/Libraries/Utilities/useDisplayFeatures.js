/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict-local
 * @format
 */

import Dimensions from './Dimensions';
import {type DisplayFeature} from './NativeDeviceInfo';
import {useEffect, useState} from 'react';

/**
 * React hook that provides the display features (such as a fold, a hinge or
 * a front-facing camera cutout) that content should avoid covering.
 * Automatically updates when the device posture changes.
 *
 * Populated on devices that report reserved display regions (iPhone Duo on
 * iOS 27.1+); empty elsewhere. See the `DisplayFeature` type.
 */
export default function useDisplayFeatures(): ReadonlyArray<DisplayFeature> {
  const [displayFeatures, setDisplayFeatures] = useState(() =>
    Dimensions.getDisplayFeatures(),
  );
  useEffect(() => {
    function handleChange() {
      setDisplayFeatures(Dimensions.getDisplayFeatures());
    }
    const subscription = Dimensions.addEventListener('change', handleChange);
    // We might have missed an update between calling `getDisplayFeatures` in
    // render and `addEventListener` in this handler.
    handleChange();
    return () => {
      subscription.remove();
    };
  }, []);
  return displayFeatures;
}
