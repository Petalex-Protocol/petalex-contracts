// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {TestHelpers} from "../TestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {ActionRegistry} from "src/actions/ActionRegistry.sol";

contract ActionRegistryTest is TestHelpers {
    function setUp() public {}

    function test_RevertSettingActionExecutorToAddressWhenNotOwner() public {
        actionRegistry = new ActionRegistry(address(this));
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, user));
        vm.prank(user);
        actionRegistry.setActionExecutor(address(0x2));
    }

    function test_SettingActionExecutor() public {
        _deployProxyContracts();
        actionRegistry = new ActionRegistry(address(this));
        actionExecutor =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));
        actionRegistry.setActionExecutor(address(actionExecutor));
    }

    function test_RevertSetActionIdWhenNotExecutor() public {
        _deployProxyContracts();
        actionRegistry = new ActionRegistry(address(this));
        actionExecutor =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));
        actionRegistry.setActionExecutor(address(actionExecutor));

        PullToken pullToken = new PullToken();
        vm.expectRevert(bytes("NAE"));
        actionRegistry.setActionIdToAddress(1, address(pullToken));
    }

    function test_SettingActionIdAsExecutor() public {
        _deployProxyContracts();
        actionRegistry = new ActionRegistry(address(this));
        actionExecutor =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));
        actionRegistry.setActionExecutor(address(actionExecutor));

        PullToken pullToken = new PullToken();
        vm.prank(address(actionExecutor));
        actionRegistry.setActionIdToAddress(1, address(pullToken));
    }
}
