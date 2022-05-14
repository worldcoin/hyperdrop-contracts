// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract TestToken is ERC20("Test Token", "TEST", 18) {
    function issue(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
