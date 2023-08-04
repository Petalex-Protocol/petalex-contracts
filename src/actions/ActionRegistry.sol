// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ActionRegistry is Ownable {
    event ActionIdToAddressSet(uint8 actionId, address actionAddress);
    event ActionExecutorSet(address actionExecutorAddress);

    mapping(uint8 => address) private _actionIdToAddress;
    address private _actionExecutor;

    constructor(address owner) Ownable(owner) {}

    function setActionExecutor(address actionExecutor) public onlyOwner {
        _actionExecutor = actionExecutor;
        emit ActionExecutorSet(actionExecutor);
    }

    function setActionIdToAddress(uint8 actionId, address actionAddress) public {
        require(msg.sender == _actionExecutor, "NAE");
        _actionIdToAddress[actionId] = actionAddress;
        emit ActionIdToAddressSet(actionId, actionAddress);
    }

    function getActionAddress(uint8 actionId) public view returns (address actionAddr) {
        actionAddr = _actionIdToAddress[actionId];
    }
}
