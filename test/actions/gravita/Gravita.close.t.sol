// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {GravitaOpen} from "src/actions/gravita/GravitaOpen.sol";
import {GravitaClose} from "src/actions/gravita/GravitaClose.sol";
import {IVesselManager} from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";

contract GravitaCloseTest is ActionTestHelpers {
    uint256 _mainnetFork;

    GravitaClose gravitaClose;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        gravitaClose = new GravitaClose(MAINNET_BORROWER_OPERATIONS, 1);
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function test_RevertCloseVesselIfNotEnoughDebtToRepay() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaClose));
        PullToken pullToken = new PullToken();
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(gravitaOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](3);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        (address prevId, address nextId) = _getHints(col, debt);
        PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
        GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
        GravitaClose.Params memory closeParams = GravitaClose.Params(MAINNET_WETH);
        callData[1] = abi.encode(params);
        callData[0] = abi.encode(pullParams);
        callData[2] = abi.encode(closeParams);
        uint8[] memory actionIds = new uint8[](3);
        actionIds[1] = 3;
        actionIds[0] = 2;
        actionIds[2] = 1;

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.expectRevert(bytes("BorrowerOps: Caller doesnt have enough debt tokens to make repayment"));
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }

    function test_CloseVessel() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaClose));
        PullToken pullToken = new PullToken();
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        actionExecutor.setActionIdToAddress(3, address(gravitaOpen));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](4);
        uint8[] memory actionIds = new uint8[](4);
        uint256 col = 10e18;
        uint256 debt = 5000e18;
        uint256 debtFee = (debt * 5) / 1000;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, col);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);
            GravitaClose.Params memory closeParams = GravitaClose.Params(MAINNET_WETH);
            PullToken.Params memory pullDebtParams = PullToken.Params(MAINNET_GRAI, user, debtFee);
            callData[1] = abi.encode(params);
            callData[0] = abi.encode(pullParams);
            callData[3] = abi.encode(closeParams);
            callData[2] = abi.encode(pullDebtParams);

            actionIds[1] = 3;
            actionIds[0] = 2;
            actionIds[2] = 2;
            actionIds[3] = 1;
        }

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, col);

        vm.prank(user);
        IERC20(MAINNET_GRAI).approve(proxyAddress, debtFee);

        deal(MAINNET_GRAI, user, debtFee);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 4);
        assertEq(response[3], bytes32(uint256(uint160(MAINNET_WETH))));

        assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselStatus(MAINNET_WETH, proxyAddress), 2);
    }
}
