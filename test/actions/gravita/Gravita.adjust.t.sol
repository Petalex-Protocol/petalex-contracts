// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {GravitaOpen} from "src/actions/gravita/GravitaOpen.sol";
import {GravitaAdjust} from "src/actions/gravita/GravitaAdjust.sol";
import {IVesselManager} from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";

contract GravitaAdjustTest is ActionTestHelpers {
    uint256 _mainnetFork;

    GravitaAdjust gravitaAdjust;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        gravitaAdjust = new GravitaAdjust(MAINNET_BORROWER_OPERATIONS, MAINNET_GRAI);
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function test_CanAddCollateral() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaAdjust));
        PullToken pullToken = new PullToken();
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(gravitaOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](3);
        uint8[] memory actionIds = new uint8[](3);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getHints(col + col, debt + debt);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col + col);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
            GravitaAdjust.Params memory adjustParams =
                GravitaAdjust.Params(MAINNET_WETH, col, 0, debt, true, prevIdAdjust, nextIdAdjust);
            callData[1] = abi.encode(params);
            callData[0] = abi.encode(pullParams);
            callData[2] = abi.encode(adjustParams);

            actionIds[1] = 3;
            actionIds[0] = 2;
            actionIds[2] = 1;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col + col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 3);
        assertEq(response[2], bytes32(debt));

        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselStatus(MAINNET_WETH, proxyAddress), 1);
        assertEq(
            IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselDebt(MAINNET_WETH, proxyAddress),
            debt + debt + 200e18 + ((debt * 2 * 5) / 1000)
        );
        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselColl(MAINNET_WETH, proxyAddress), col + col);
    }

    function test_RevertRepayDebtIfNotAvailable() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaAdjust));
        PullToken pullToken = new PullToken();
        SendToken sendToken = new SendToken();
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(gravitaOpen));
        actionExecutor.setActionIdToAddress(4, address(sendToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](4);
        uint8[] memory actionIds = new uint8[](4);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getHints(col + col, debt + debt);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
            GravitaAdjust.Params memory adjustParams =
                GravitaAdjust.Params(MAINNET_WETH, col, 0, debt, true, prevIdAdjust, nextIdAdjust);
            SendToken.Params memory sendDebtParams = SendToken.Params(MAINNET_GRAI, user, debt);
            callData[1] = abi.encode(params);
            callData[0] = abi.encode(pullParams);
            callData[3] = abi.encode(adjustParams);
            callData[2] = abi.encode(sendDebtParams);

            actionIds[1] = 3;
            actionIds[0] = 2;
            actionIds[2] = 4;
            actionIds[3] = 1;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col + col);

        vm.expectRevert(bytes("SafeERC20: low-level call failed"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_RevertAdjustIfNotOpen() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaAdjust));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint8[] memory actionIds = new uint8[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevIdAdjust, address nextIdAdjust) = _getHints(col + col, debt + debt);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
            GravitaAdjust.Params memory adjustParams =
                GravitaAdjust.Params(MAINNET_WETH, col, 0, debt, true, prevIdAdjust, nextIdAdjust);
            callData[0] = abi.encode(pullParams);
            callData[1] = abi.encode(adjustParams);

            actionIds[0] = 2;
            actionIds[1] = 1;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col + col);

        vm.expectRevert(bytes("BorrowerOps: Vessel does not exist or is closed"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_CanRepayDebt() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaAdjust));
        PullToken pullToken = new PullToken();
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(gravitaOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](3);
        uint8[] memory actionIds = new uint8[](3);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        uint256 debtAdjust = 2000e18;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getHints(col, debt - debtAdjust);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
            GravitaAdjust.Params memory adjustParams =
                GravitaAdjust.Params(MAINNET_WETH, 0, 0, debtAdjust, false, prevIdAdjust, nextIdAdjust);
            callData[1] = abi.encode(params);
            callData[0] = abi.encode(pullParams);
            callData[2] = abi.encode(adjustParams);

            actionIds[1] = 3;
            actionIds[0] = 2;
            actionIds[2] = 1;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 3);
        assertEq(response[2], bytes32(debtAdjust));

        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselStatus(MAINNET_WETH, proxyAddress), 1);
        assertEq(
            IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselDebt(MAINNET_WETH, proxyAddress),
            debt - debtAdjust + 200e18 + ((debt * 5) / 1000)
        );
        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselColl(MAINNET_WETH, proxyAddress), col);
    }

    function test_CanRepayDebtAndWithdrawCollateral() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaAdjust));
        PullToken pullToken = new PullToken();
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(gravitaOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](3);
        uint8[] memory actionIds = new uint8[](3);
        uint256 col = 10e18;
        uint256 colWithdraw = 1e18;
        uint256 debt = 5000e18;
        uint256 debtAdjust = 2000e18;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            (address prevIdAdjust, address nextIdAdjust) = _getHints(col, debt - debtAdjust);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
            GravitaAdjust.Params memory adjustParams =
                GravitaAdjust.Params(MAINNET_WETH, 0, colWithdraw, debtAdjust, false, prevIdAdjust, nextIdAdjust);
            callData[1] = abi.encode(params);
            callData[0] = abi.encode(pullParams);
            callData[2] = abi.encode(adjustParams);

            actionIds[1] = 3;
            actionIds[0] = 2;
            actionIds[2] = 1;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 3);
        assertEq(response[2], bytes32(debtAdjust));

        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselStatus(MAINNET_WETH, proxyAddress), 1);
        assertEq(
            IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselDebt(MAINNET_WETH, proxyAddress),
            debt - debtAdjust + 200e18 + ((debt * 5) / 1000)
        );
        assertEq(
            IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselColl(MAINNET_WETH, proxyAddress), col - colWithdraw
        );
    }
}
