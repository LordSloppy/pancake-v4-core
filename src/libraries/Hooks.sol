// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.24;

import {IHooks} from "../interfaces/IHooks.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {Encoded} from "./math/Encoded.sol";
import {LPFeeLibrary} from "./LPFeeLibrary.sol";
import {ParametersHelper} from "./math/ParametersHelper.sol";

library Hooks {
    using Encoded for bytes32;
    using ParametersHelper for bytes32;
    using LPFeeLibrary for uint24;

    bytes4 constant NO_OP_SELECTOR = bytes4(keccak256(abi.encodePacked("NoOp")));

    /// @notice Hook has no-op defined, but lacking before* call
    error NoOpHookMissingBeforeCall();

    /// @notice Hook config validation failed
    /// 1. either registration bitmap mismatch
    /// 2. or fee related config misconfigured

    error HookConfigValidationError();

    /// @notice Hook did not return its selector
    error InvalidHookResponse();

    /// @notice Utility function intended to be used in pool initialization to ensure
    /// the hook contract's hooks registration bitmap match the configration in the pool key
    function validateHookConfig(PoolKey memory poolKey) internal view {
        uint16 bitmapInParameters = poolKey.parameters.getHooksRegistrationBitmap();
        if (address(poolKey.hooks) == address(0)) {
            /// @notice If the hooks address is 0, then the bitmap must be 0,
            /// in the same time, the dynamic fee should be disabled as well
            if (bitmapInParameters == 0 && !poolKey.fee.isDynamicLPFee()) {
                return;
            }
            revert HookConfigValidationError();
        }

        if (poolKey.hooks.getHooksRegistrationBitmap() != bitmapInParameters) {
            revert HookConfigValidationError();
        }
    }

    /// @return true if parameter has offset enabled
    function hasOffsetEnabled(bytes32 parameters, uint8 offset) internal pure returns (bool) {
        return parameters.decodeBool(offset);
    }

    /// @notice checks if hook should be called -- based on 2 factors:
    /// 1. whether pool.parameters has the callback offset registered
    /// 2. whether msg.sender is the hook itself
    function shouldCall(bytes32 parameters, uint8 offset, IHooks hook) internal view returns (bool) {
        return hasOffsetEnabled(parameters, offset) && address(hook) != msg.sender;
    }

    /// @dev Verify hook return value matches no-op when these 2 conditions are met
    ///   1) Hook have permission for no-op
    ///   2) Return value is no-op selector
    function isValidNoOpCall(bytes32 parameters, uint8 noOpOffset, bytes4 selector) internal pure returns (bool) {
        return hasOffsetEnabled(parameters, noOpOffset) && selector == NO_OP_SELECTOR;
    }
}
