// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquityHelpers} from "./LiquityHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {LiquityOpen} from "src/actions/liquity/LiquityOpen.sol";
import {LiquityClose} from "src/actions/liquity/LiquityClose.sol";
import {ITroveManager} from "src/actions/liquity/Interfaces/ITroveManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GravitaCloseTest is LiquityHelpers {
    uint256 _mainnetFork;

    LiquityClose liquityClose;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        liquityClose = new LiquityClose(MAINNET_LIQUITY_BORROWER_OPERATIONS);
    }

    function test_RevertCloseTroveIfNotEnoughDebtToRepay() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityClose));
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(3, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        (address prevId, address nextId) = _getLiquityHints(col, debt);
        LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
        callData[0] = abi.encode(params);
        callData[1] = abi.encode("0x");
        uint8[] memory actionIds = new uint8[](2);
        actionIds[0] = 3;
        actionIds[1] = 1;

        deal(proxyAddress, col);

        vm.expectRevert(bytes("BorrowerOps: Caller doesnt have enough LUSD to make repayment"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_CloseTrove() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityClose));
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(3, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        uint256 debtFee = ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getBorrowingFee(debt);
        (address prevId, address nextId) = _getLiquityHints(col, debt);
        LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
        callData[0] = abi.encode(params);
        callData[1] = abi.encode("0x");
        uint8[] memory actionIds = new uint8[](2);
        actionIds[0] = 3;
        actionIds[1] = 1;

        deal(proxyAddress, col);
        deal(MAINNET_LIQUITY_LUSD, proxyAddress, debtFee);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertEq(response[1], bytes32("OK"));

        assertEq(ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveStatus(proxyAddress), 2);
    }
}
