// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";
import {FlashUniV3} from "src/actions/flashloan/FlashUniV3.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract FlashUniV3Test is ActionTestHelpers {
    uint256 mainnetFork;

    SendToken sendToken;
    PullToken pullToken;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17814506);

        sendToken = new SendToken();
        pullToken = new PullToken();
        deal(MAINNET_WETH, user, 1000000e18);
    }

    function test_CanFlash() public {
        vm.selectFork(mainnetFork);
        _deployActionExecutorAndProxy();
        FlashUniV3 flashUniV3 = new FlashUniV3(MAINNET_UNISWAP_FACTORY, address(actionExecutor), address(petalexProxy));
        actionExecutor.setActionIdToAddress(1, address(sendToken));
        actionExecutor.setActionIdToAddress(2, address(flashUniV3));
        actionExecutor.setActionIdToAddress(3, address(pullToken));
        uint256 tokenId = mintNFT(user);

        (bool success, bytes memory data) =
            address(petalexProxy).call(abi.encodeWithSignature(GET_PROXY_ADDRESS_FOR_TOKEN_SIGNATURE, tokenId));
        assertEq(success, true);
        address proxyAddress = abi.decode(data, (address));
        uint24 fee = 3000;
        uint256 feeAmount = Math.mulDiv(10e18, 3000, 1000000);

        bytes[] memory callData = new bytes[](3);
        {
            address pool = _getUniswapV3PoolAddress(MAINNET_WETH, MAINNET_USDC, fee);
            address token0 = IUniswapV3Pool(pool).token0();
            address token1 = IUniswapV3Pool(pool).token1();

            FlashUniV3.FlashParams memory flashParams = FlashUniV3.FlashParams(
                token0, token1, pool, token0 == MAINNET_WETH ? 10e18 : 0, token1 == MAINNET_WETH ? 10e18 : 0
            );
            callData[0] = abi.encode(flashParams);
            PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, feeAmount);
            callData[1] = abi.encode(pullParams);
            SendToken.Params memory params = SendToken.Params(MAINNET_WETH, address(flashUniV3), 10e18 + feeAmount);
            callData[2] = abi.encode(params);
        }
        uint8[] memory actionIds = new uint8[](3);
        actionIds[0] = 2;
        actionIds[1] = 3;
        actionIds[2] = 1;

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, feeAmount);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 3);
        assertEq(IERC20(MAINNET_WETH).balanceOf(proxyAddress), 0);
        assertEq(IERC20(MAINNET_WETH).balanceOf(user), 1000000e18 - feeAmount);
    }
}
