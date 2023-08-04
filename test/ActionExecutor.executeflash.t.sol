// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {TestHelpers} from "./TestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";

contract ActionExecutorExecuteFlashTest is TestHelpers {
    function setUp() public {}

    function test_RevertSettingActionIdToAddressWhenNotOwner() public {
        _deployProxyContracts();
        _deployActions();

        bytes[] memory callData = new bytes[](1);
        callData[0] = "0x";
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        ActionExecutor.ActionList memory actionList =
            ActionExecutor.ActionList({callData: callData, actionIds: actionIds, tokenId: 1});

        vm.expectRevert(bytes("Not authorized"));
        actionExecutor.executeActionsFromFL(actionList);
    }
}
