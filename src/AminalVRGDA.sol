// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../lib/VRGDAs/src/LinearVRGDA.sol";

contract AminalVRGDA is LinearVRGDA {
    bool public initialized;

    constructor(
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) LinearVRGDA(_targetPrice, _priceDecayPercent, _perTimeUnit) {
        initialized = true;
    }

    // Accessing the initialized getter caused an error, but accessing
    // isInitialized() worked. Could refactor this at some point.
    function isInitialized() public view returns (bool) {
        return initialized;
    }
}
