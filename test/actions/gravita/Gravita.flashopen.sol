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
import {FlashUniV3} from "src/actions/flashloan/FlashUniV3.sol";
import {UniswapV3SwapExactInput} from "src/actions/exchange/UniswapV3SwapExactInput.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract GravitaFlashOpenTest is ActionTestHelpers {
    uint256 _mainnetFork;

    GravitaOpen gravitaOpen;
    FlashUniV3 flashUniV3;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        _deployActionExecutorAndProxy();
        gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        flashUniV3 = new FlashUniV3(MAINNET_UNISWAP_FACTORY, address(actionExecutor), address(petalexProxy));
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function _deploySubActions() internal {
        actionExecutor.setActionIdToAddress(3, address(flashUniV3));
        actionExecutor.setActionIdToAddress(1, address(gravitaOpen));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));

        UniswapV3SwapExactInput exchange = new UniswapV3SwapExactInput(MAINNET_SWAP_ROUTER);
        actionExecutor.setActionIdToAddress(4, address(exchange));
        SendToken sendToken = new SendToken();
        actionExecutor.setActionIdToAddress(5, address(sendToken));
    }

    function test_OpenFlashVesselOnMaximumLeverage() public {
        vm.selectFork(_mainnetFork);
        _deploySubActions();

        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](5);
        uint8[] memory actionIds = new uint8[](5);
        uint256 col = 10e18;
        uint256 debt = 16000e18;
        uint256 startAmount = 18e17;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, startAmount);
            GravitaOpen.Params memory params = GravitaOpen.Params(MAINNET_WETH, col, debt, prevId, nextId);

            address pool = _getUniswapV3PoolAddress(MAINNET_WETH, MAINNET_USDC, 3000);
            address token0 = IUniswapV3Pool(pool).token0();
            address token1 = IUniswapV3Pool(pool).token1();

            FlashUniV3.FlashParams memory flashParams = FlashUniV3.FlashParams(
                token0, token1, pool, token0 == MAINNET_WETH ? 10e18 : 0, token1 == MAINNET_WETH ? 10e18 : 0
            );
            callData[0] = abi.encode(flashParams);
            UniswapV3SwapExactInput.Params memory swapParams = UniswapV3SwapExactInput.Params(
                MAINNET_GRAI,
                debt,
                0,
                abi.encodePacked(MAINNET_GRAI, uint24(500), MAINNET_USDC, uint24(500), MAINNET_WETH)
            );
            SendToken.Params memory sendParams =
                SendToken.Params(MAINNET_WETH, address(flashUniV3), 10e18 + Math.mulDiv(10e18, 3000, 1000000));

            callData[2] = abi.encode(params);
            callData[1] = abi.encode(pullParams);
            callData[3] = abi.encode(swapParams);
            callData[4] = abi.encode(sendParams);

            actionIds[2] = 1;
            actionIds[1] = 2;
            actionIds[0] = 3;
            actionIds[3] = 4;
            actionIds[4] = 5;
        }

        {
            vm.prank(user);
            IERC20(MAINNET_WETH).approve(proxyAddress, startAmount);

            vm.prank(user);
            bytes32[] memory response =
                actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
            assertEq(response.length, 5);

            assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselStatus(MAINNET_WETH, proxyAddress), 1);
            assertEq(
                IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselDebt(MAINNET_WETH, proxyAddress),
                debt + 200e18 + ((debt * 5) / 1000)
            );
            assertEq(IVesselManager(address(MAINNET_VESSEL_MANAGER)).getVesselColl(MAINNET_WETH, proxyAddress), col);
        }
    }
}
