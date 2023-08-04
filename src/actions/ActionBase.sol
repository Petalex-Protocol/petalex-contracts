// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ActionBase {
    enum ActionType {
        NORMAL,
        FLASHLOAN
    }

    function actionType() public pure virtual returns (ActionType) {
        return ActionType.NORMAL;
    }

    function executeAction(bytes memory _callData) public payable virtual returns (bytes32);
}
