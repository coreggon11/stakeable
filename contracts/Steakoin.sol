// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Stakeable.sol";

contract Steakoin is Stakeable, Ownable {
    constructor() Stakeable("Steakoin", "STK") Ownable() {
        _mint(msg.sender, 2000 * 10**18);
    }
}
