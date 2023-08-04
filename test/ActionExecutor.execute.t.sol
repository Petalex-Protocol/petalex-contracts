// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {TestHelpers} from "./TestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {ActionRegistry} from "src/actions/ActionRegistry.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";

contract ActionExecutorExecuteTest is TestHelpers {
    function setUp() public {}

    function test_RevertSettingActionIdToAddressWhenNotOwner() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, user));
        actionExecutor.setActionIdToAddress(1, address(0x2));
    }

    function test_SettingActionIdToAddress() public {
        _deployProxyContracts();
        _deployActions();

        actionExecutor.setActionIdToAddress(1, address(0x2));
    }

    function test_RevertSetActionIdWhenRegistryNotSet() public {
        _deployProxyContracts();
        actionRegistry = new ActionRegistry(address(this));
        actionExecutor =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));

        IPetalexNFT(address(petalexProxy)).setActionExecutor(address(actionExecutor));

        PullToken pullToken = new PullToken();
        vm.expectRevert(bytes("NAE"));
        actionExecutor.setActionIdToAddress(1, address(pullToken));
    }

    function test_RevertExecuteActionListWhenNotAuthority() public {
        _deployProxyContracts();
        actionRegistry = new ActionRegistry(address(this));
        ActionExecutor actionExecutorAlt =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));
        actionExecutor =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));
        actionRegistry.setActionExecutor(address(actionExecutorAlt));

        IPetalexNFT(address(petalexProxy)).setActionExecutor(address(actionExecutorAlt));

        PullToken pullToken = new PullToken();
        actionExecutorAlt.setActionIdToAddress(1, address(pullToken));

        vm.prank(user);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory data = abi.encodePacked("0x");
        // owner of dsproxy is actionExecutorAlt at this point, but actionExecutor is not an authority
        IPetalexNFT(address(petalexProxy)).mintBatch(user, ids, data);

        bytes[] memory callData = new bytes[](1);
        callData[0] = "0x";
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        ActionExecutor.ActionList memory actionList =
            ActionExecutor.ActionList({callData: callData, actionIds: actionIds, tokenId: 1});
        vm.expectRevert(bytes("NA"));
        vm.prank(user);
        actionExecutor.executeActionList(actionList);
    }

    function test_RevertExecuteActionListWhenNotOwnerOfToken() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory data = abi.encodePacked("0x");
        IPetalexNFT(address(petalexProxy)).mintBatch(user, ids, data);

        bytes[] memory callData = new bytes[](1);
        callData[0] = "0x";
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        ActionExecutor.ActionList memory actionList =
            ActionExecutor.ActionList({callData: callData, actionIds: actionIds, tokenId: 2});
        vm.expectRevert(bytes("Not owner of token"));
        vm.prank(user);
        actionExecutor.executeActionList(actionList);
    }

    function test_RevertExecuteActionListWhenActionListLengthMismatch() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory data = abi.encodePacked("0x");
        IPetalexNFT(address(petalexProxy)).mintBatch(user, ids, data);

        bytes[] memory callData = new bytes[](1);
        callData[0] = "0x";
        uint8[] memory actionIds = new uint8[](2);
        actionIds[0] = 1;
        actionIds[1] = 2;

        ActionExecutor.ActionList memory actionList =
            ActionExecutor.ActionList({callData: callData, actionIds: actionIds, tokenId: 1});
        vm.expectRevert(bytes("Length mismatch"));
        vm.prank(user);
        actionExecutor.executeActionList(actionList);
    }

    function test_RevertExecuteActionListWhenActionNotExist() public {
        _deployProxyContracts();
        _deployActions();

        vm.prank(user);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory data = abi.encodePacked("0x");
        IPetalexNFT(address(petalexProxy)).mintBatch(user, ids, data);

        bytes[] memory callData = new bytes[](1);
        callData[0] = "0x";
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 2;

        ActionExecutor.ActionList memory actionList =
            ActionExecutor.ActionList({callData: callData, actionIds: actionIds, tokenId: 1});
        vm.expectRevert(bytes("Action not set"));
        vm.prank(user);
        actionExecutor.executeActionList(actionList);
    }
}
