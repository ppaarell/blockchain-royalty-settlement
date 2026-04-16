// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSD is ERC20 {
    constructor() ERC20("Test USD", "tUSD") {
        _mint(msg.sender, 1_000_000e18); // mint 1 juta tUSD ke deployer
    }
}
