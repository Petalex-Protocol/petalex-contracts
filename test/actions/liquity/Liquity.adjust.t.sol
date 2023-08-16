// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquityHelpers} from "./LiquityHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {LiquityOpen} from "src/actions/liquity/LiquityOpen.sol";
import {LiquityAdjust} from "src/actions/liquity/LiquityAdjust.sol";
import {ITroveManager} from "src/actions/liquity/Interfaces/ITroveManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";

contract LiquityAdjustTest is LiquityHelpers {
    uint256 _mainnetFork;

    LiquityAdjust liquityAdjust;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        liquityAdjust = new LiquityAdjust(MAINNET_LIQUITY_BORROWER_OPERATIONS, MAINNET_LIQUITY_LUSD);
    }

    function test_CanAddCollateral() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityAdjust));        
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(3, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint8[] memory actionIds = new uint8[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevId, address nextId) = _getLiquityHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getLiquityHints(col + col, debt + debt);
            LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
            LiquityAdjust.Params memory adjustParams =
                LiquityAdjust.Params(1e18, col, 0, debt, true, prevIdAdjust, nextIdAdjust);
            callData[0] = abi.encode(params);
            callData[1] = abi.encode(adjustParams);

            actionIds[0] = 3;
            actionIds[1] = 1;
        }

        deal(proxyAddress, col + col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertEq(response[1], bytes32(debt));

        assertEq(ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveStatus(proxyAddress), 1);
        assertEq(
            ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveDebt(proxyAddress),
            debt + debt + 200e18 + ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getBorrowingFee(debt + debt)
        );
        assertEq(ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveColl(proxyAddress), col + col);
    }

    function test_RevertRepayDebtIfNotAvailable() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityAdjust));
        
        SendToken sendToken = new SendToken();
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(3, address(liquityOpen));
        actionExecutor.setActionIdToAddress(4, address(sendToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](3);
        uint8[] memory actionIds = new uint8[](3);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevId, address nextId) = _getLiquityHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getLiquityHints(col, debt);
            LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
            LiquityAdjust.Params memory adjustParams =
                LiquityAdjust.Params(1e18, col, 0, 1000e18, false, prevIdAdjust, nextIdAdjust);
            SendToken.Params memory sendDebtParams = SendToken.Params(MAINNET_LIQUITY_LUSD, user, debt);
            callData[0] = abi.encode(params);
            callData[1] = abi.encode(adjustParams);
            callData[2] = abi.encode(sendDebtParams);

            actionIds[0] = 3;
            actionIds[1] = 4;
            actionIds[2] = 1;
        }

        deal(proxyAddress, col);

        vm.expectRevert(bytes("Amount can't be 0"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_RevertAdjustIfNotOpen() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityAdjust));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](1);
        uint8[] memory actionIds = new uint8[](1);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevIdAdjust, address nextIdAdjust) = _getLiquityHints(col, debt);
            LiquityAdjust.Params memory adjustParams =
                LiquityAdjust.Params(1e18, col, 0, debt, true, prevIdAdjust, nextIdAdjust);
            callData[0] = abi.encode(adjustParams);

            actionIds[0] = 1;
        }

        deal(proxyAddress, col + col);

        vm.expectRevert(bytes("BorrowerOps: Trove does not exist or is closed"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_CanRepayDebt() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityAdjust));
        
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(3, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint8[] memory actionIds = new uint8[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        uint256 debtAdjust = 2000e18;
        {
            (address prevId, address nextId) = _getLiquityHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getLiquityHints(col, debt);
            LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
            LiquityAdjust.Params memory adjustParams =
                LiquityAdjust.Params(1e18, 0, 0, debtAdjust, false, prevIdAdjust, nextIdAdjust);
            callData[0] = abi.encode(params);
            callData[1] = abi.encode(adjustParams);

            actionIds[0] = 3;
            actionIds[1] = 1;
        }

        deal(proxyAddress, col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertEq(response[1], bytes32(debtAdjust));

        assertEq(ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveStatus(proxyAddress), 1);
        assertEq(
            ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveDebt(proxyAddress),
            debt - debtAdjust + 200e18 + ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getBorrowingFee(debt)
        );
        assertEq(ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveColl(proxyAddress), col);
    }

    function test_CanRepayDebtAndWithdrawCollateral() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(liquityAdjust));        
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(3, address(liquityOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint8[] memory actionIds = new uint8[](2);
        uint256 col = 10e18;
        uint256 colWithdraw = 1e18;
        uint256 debt = 5000e18;
        uint256 debtAdjust = 2000e18;
        {
            (address prevId, address nextId) = _getLiquityHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getLiquityHints(col, debt);
            LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);
            LiquityAdjust.Params memory adjustParams =
                LiquityAdjust.Params(1e18, 0, colWithdraw, debtAdjust, false, prevIdAdjust, nextIdAdjust);
            callData[0] = abi.encode(params);
            callData[1] = abi.encode(adjustParams);

            actionIds[0] = 3;
            actionIds[1] = 1;
        }

        deal(proxyAddress, col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertEq(response[1], bytes32(debtAdjust));

        assertEq(ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveStatus(proxyAddress), 1);
        assertEq(
            ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveDebt(proxyAddress),
            debt - debtAdjust + 200e18 + ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getBorrowingFee(debt)
        );
        assertEq(
            ITroveManager(MAINNET_LIQUITY_TROVE_MANAGER).getTroveColl(proxyAddress), col - colWithdraw
        );
    }
}
