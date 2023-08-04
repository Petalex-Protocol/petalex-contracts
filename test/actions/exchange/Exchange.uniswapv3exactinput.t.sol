// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {UniswapV3SwapExactInput} from "src/actions/exchange/UniswapV3SwapExactInput.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";

contract ExchangeUniswapV3ExactInputTest is ActionTestHelpers {
    uint256 _mainnetFork;

    UniswapV3SwapExactInput exchange;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        exchange = new UniswapV3SwapExactInput(MAINNET_SWAP_ROUTER);
        deal(MAINNET_WETH, user, 1e18);
    }

    function test_SwapWethForUsdc() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(exchange));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, 1e18);
        UniswapV3SwapExactInput.Params memory params = UniswapV3SwapExactInput.Params(
            MAINNET_WETH, 1e18, 0, abi.encodePacked(MAINNET_WETH, uint24(500), MAINNET_USDC)
        );
        callData[1] = abi.encode(params);
        callData[0] = abi.encode(pullParams);
        uint8[] memory actionIds = new uint8[](2);
        actionIds[1] = 1;
        actionIds[0] = 2;

        vm.prank(user);
        IERC20(MAINNET_WETH).approve(proxyAddress, 1e18);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 2);
        assertApproxEqAbs(uint256(response[1]), 1800e6, 200e6); // eth price was about 1800 at the rolled block
        assertApproxEqAbs(IERC20(MAINNET_USDC).balanceOf(proxyAddress), 1800e6, 200e6);
    }

    function test_RevertSwapWethForUsdcIfNotApproved() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(exchange));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](2);
        PullToken.Params memory pullParams = PullToken.Params(MAINNET_WETH, user, 1e18);
        UniswapV3SwapExactInput.Params memory params = UniswapV3SwapExactInput.Params(
            MAINNET_WETH, 1e18, 0, abi.encodePacked(MAINNET_WETH, uint24(500), MAINNET_USDC)
        );
        callData[1] = abi.encode(params);
        callData[0] = abi.encode(pullParams);
        uint8[] memory actionIds = new uint8[](2);
        actionIds[1] = 1;
        actionIds[0] = 2;

        vm.expectRevert();
        vm.prank(user);
        actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
    }
}
