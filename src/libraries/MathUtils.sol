// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library mathUtils {
    function uncheckedDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            result := div(a, b)
        }
    }

    function cappedSub(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b > a) return 0;

        unchecked {
            return a - b;
        }
    }
}
