// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquityHelpers} from "./LiquityHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {LiquityOpen} from "src/actions/liquity/LiquityOpen.sol";
import {ITroveManager} from "src/actions/liquity/Interfaces/ITroveManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";

contract LiquityOpenTest is LiquityHelpers {
    uint256 _mainnetFork;

    LiquityOpen liquityOpen;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        deal(user, 1000000e18);
    }

    function test_RevertOpenTroveIfNotMinDebt() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](1);
        uint256 col = 10e18;
        uint256 debt = 1000e18;
        (address prevId, address nextId) = _getLiquityHints(col, debt);
        LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        deal(proxyAddress, col);
        vm.expectRevert(bytes("BorrowerOps: Trove's net debt must be greater than minimum"));
        vm.prank(user);
        actionExecutor.executeActionList{value: col}(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_RevertOpenTroveIfDebtTooMuch() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](1);
        uint256 col = 10e18;
        
        uint256 debt = 100000e18;
        (address prevId, address nextId) = _getLiquityHints(col, debt);
        LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        deal(proxyAddress, col);
        vm.expectRevert(bytes("BorrowerOps: An operation that would result in ICR < MCR is not permitted"));
        vm.prank(user);
        actionExecutor.executeActionList{value: col}(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_OpenTrove() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](1);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        (address prevId, address nextId) = _getLiquityHints(col, debt);
        LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
        callData[0] = abi.encode(params);
        uint8[] memory actionIds = new uint8[](1);
        actionIds[0] = 1;

        deal(proxyAddress, col);
        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList{value: col}(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(debt));

        assertEq(ITroveManager(address(MAINNET_LIQUITY_TROVE_MANAGER)).getTroveStatus(proxyAddress), 1);
        assertApproxEqAbs(
            ITroveManager(address(MAINNET_LIQUITY_TROVE_MANAGER)).getTroveDebt(proxyAddress),
            debt + 200e18 + ((debt * 5) / 1000),
            1e18
        );
        assertEq(ITroveManager(address(MAINNET_LIQUITY_TROVE_MANAGER)).getTroveColl(proxyAddress), col);
    }

    function test_OpenTroveAndSendDebt() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityOpen));
        SendToken sendToken = new SendToken();
        actionExecutor.setActionIdToAddress(3, address(sendToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint8[] memory actionIds = new uint8[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevId, address nextId) = _getLiquityHints(col, debt);
            LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
            SendToken.Params memory sendParams = SendToken.Params(MAINNET_LIQUITY_LUSD, user, debt);
            callData[0] = abi.encode(params);
            callData[1] = abi.encode(sendParams);

            actionIds[0] = 1;
            actionIds[1] = 3;
        }

        deal(proxyAddress, col);
        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList{value: col}(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertEq(IERC20(MAINNET_LIQUITY_LUSD).balanceOf(user), debt);
    }
}
