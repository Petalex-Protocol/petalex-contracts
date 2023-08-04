// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {GravitaOpen} from "src/actions/gravita/GravitaOpen.sol";
import {IVesselManager} from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";

contract GravitaOpenTest is ActionTestHelpers {
    uint256 _mainnetFork;

    GravitaOpen gravitaOpen;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function test_RevertOpenVesselIfNotMinDebt() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaOpen));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint256 col = 10e18;
        uint256 debt = 1000e18;
        (address prevId, address nextId) = _getHints(col, debt);
        PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
        GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
        callData[1] = abi.encode(params);
        callData[0] = abi.encode(pullParams);
        uint8[] memory actionIds = new uint8[](2);
        actionIds[1] = 1;
        actionIds[0] = 2;

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.expectRevert(bytes("BorrowerOps: Vessel's net debt must be greater than minimum"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_RevertOpenVesselIfDebtTooMuch() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaOpen));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint256 col = 10e18;
        uint256 debt = 100000e18;
        (address prevId, address nextId) = _getHints(col, debt);
        PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
        GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
        callData[1] = abi.encode(params);
        callData[0] = abi.encode(pullParams);
        uint8[] memory actionIds = new uint8[](2);
        actionIds[1] = 1;
        actionIds[0] = 2;

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.expectRevert(bytes("BorrowerOps: An operation that would result in ICR < MCR is not permitted"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_OpenVessel() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaOpen));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        (address prevId, address nextId) = _getHints(col, debt);
        PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
        GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
        callData[1] = abi.encode(params);
        callData[0] = abi.encode(pullParams);
        uint8[] memory actionIds = new uint8[](2);
        actionIds[1] = 1;
        actionIds[0] = 2;

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertEq(response[1], bytes32(debt));

        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselStatus(MAINNET_WETH, proxyAddress), 1);
        assertEq(
            IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselDebt(MAINNET_WETH, proxyAddress),
            debt + 200e18 + ((debt * 5) / 1000)
        );
        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselColl(MAINNET_WETH, proxyAddress), col);
    }

    function test_OpenVesselAndSendDebt() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaOpen));
        PullToken pullToken = new PullToken();
        SendToken sendToken = new SendToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(sendToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](3);
        uint8[] memory actionIds = new uint8[](3);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
            SendToken.Params memory sendParams = SendToken.Params(MAINNET_GRAI, user, debt);
            callData[1] = abi.encode(params);
            callData[0] = abi.encode(pullParams);
            callData[2] = abi.encode(sendParams);

            actionIds[1] = 1;
            actionIds[0] = 2;
            actionIds[2] = 3;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 3);
        assertEq(IERC20(MAINNET_GRAI).balanceOf(user), debt);
    }
}
