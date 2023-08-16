// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ActionBase {
    enum ActionType {
        NORMAL,
        FLASHLOAN
    }

    uint8 internal _actionRollWeight = 0;

    function actionType() public pure virtual returns (ActionType) {
        return ActionType.NORMAL;
    }

    function actionRollWeight() public view virtual returns (uint8) {
        return _actionRollWeight;
    }

    function executeAction(bytes memory _callData) public payable virtual returns (bytes32);
}
