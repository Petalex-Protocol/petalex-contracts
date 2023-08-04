// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

abstract contract PetalexActions {
    address internal _actionExecutor;

    // TODO: action executor actions affect different metadata values for nft

    modifier onlyActionExecutor() {
        require(msg.sender == _actionExecutor, "PetalexActions: caller is not the action executor");
        _;
    }
}