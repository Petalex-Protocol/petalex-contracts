// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {GravitaRedeem} from "src/actions/gravita/GravitaRedeem.sol";
import {GravitaOpen} from "src/actions/gravita/GravitaOpen.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IVesselManagerOperations} from "Gravita-SmartContracts/contracts/Interfaces/IVesselManagerOperations.sol";
import {ISortedVessels} from "Gravita-SmartContracts/contracts/Interfaces/ISortedVessels.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";
import {FlashUniV3} from "src/actions/flashloan/FlashUniV3.sol";
import {UniswapV3SwapExactInput} from "src/actions/exchange/UniswapV3SwapExactInput.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract GravitaRedeemTest is ActionTestHelpers {
    uint256 _mainnetFork;

    GravitaRedeem gravitaRedeem;
    FlashUniV3 flashUniV3;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        _deployActionExecutorAndProxy();        
    }

    function _getWethSpotPrice() internal view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(MAINNET_USDC_ETH_POOL);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = 10**12 / (uint256(sqrtPriceX96) / 2**96)**2;
        return price * 1e18;
    }

    function _deploySubActions() internal {
        flashUniV3 = new FlashUniV3(MAINNET_UNISWAP_FACTORY, address(actionExecutor), address(petalexProxy));
        actionExecutor.setActionIdToAddress(3, address(flashUniV3));

        UniswapV3SwapExactInput exchange = new UniswapV3SwapExactInput(MAINNET_SWAP_ROUTER);
        actionExecutor.setActionIdToAddress(4, address(exchange));

        SendToken sendToken = new SendToken();
        actionExecutor.setActionIdToAddress(5, address(sendToken));

        gravitaRedeem = new GravitaRedeem(MAINNET_VESSEL_MANAGER_OPERATIONS, MAINNET_GRAI);
        actionExecutor.setActionIdToAddress(1, address(gravitaRedeem));
    }

    function test_RedeemGrai() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        _deploySubActions();
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);
        bytes[] memory callData = new bytes[](1);
        uint8[] memory actionIds = new uint8[](1);
        uint256 debt = 50_000e18;
        uint256 adjustedDebt;
        uint256 price = _getWethSpotPrice();
        {
            (address firstRedemptionHint, uint256 partialRedemptionHintNewICR, uint256 truncatedGraiAmount ) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getRedemptionHints(
                MAINNET_WETH,
                debt,
                price,
                0
            );
            adjustedDebt = truncatedGraiAmount;   
            uint256 size = ISortedVessels(MAINNET_SORTED_VESSELS).getSize(MAINNET_WETH);
            (address hintAddress, ,) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getApproxHint(MAINNET_WETH, partialRedemptionHintNewICR, size, 1337);
            (address upperHint, address lowerHint) = ISortedVessels(MAINNET_SORTED_VESSELS).findInsertPosition(MAINNET_WETH, partialRedemptionHintNewICR, hintAddress, hintAddress);
            GravitaRedeem.Params memory params = GravitaRedeem.Params(MAINNET_WETH, truncatedGraiAmount, upperHint, lowerHint, firstRedemptionHint, partialRedemptionHintNewICR, 0, 1e18);
            callData[0] = abi.encode(params);        
            actionIds[0] = 1;
        }

        deal(MAINNET_GRAI, proxyAddress, debt);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(adjustedDebt));
        assertApproxEqAbs(IERC20(MAINNET_WETH).balanceOf(proxyAddress) * price / 1e18, debt, 3_000e18);
    }

    function test_FlashRedeemGrai() public {
        vm.selectFork(_mainnetFork);
        vm.rollFork(18171404); // 995 redemption param came in around here
        _deployActionExecutorAndProxy();
        _deploySubActions();
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](4);
        uint8[] memory actionIds = new uint8[](4);

        {
            address pool = _getUniswapV3PoolAddress(MAINNET_RETH, MAINNET_WETH, 500);
            address token0 = IUniswapV3Pool(pool).token0();
            address token1 = IUniswapV3Pool(pool).token1();

            // Flash loan 8.5 RETH
            FlashUniV3.FlashParams memory flashParams = FlashUniV3.FlashParams(
                token0, token1, pool, token0 == MAINNET_RETH ? 850e16 : 0, token1 == MAINNET_RETH ? 850e16 : 0
            );
            callData[0] = abi.encode(flashParams);
            actionIds[0] = 3;
        }

        {
            // Swap 8.5 RETH for GRAI
            UniswapV3SwapExactInput.Params memory swapParams = UniswapV3SwapExactInput.Params(
                MAINNET_RETH,
                850e16,
                0,
                abi.encodePacked(MAINNET_RETH, uint24(100), MAINNET_WETH, uint24(500), MAINNET_USDC, uint24(500), MAINNET_GRAI)
            );
            callData[1] = abi.encode(swapParams);
            actionIds[1] = 4;
        }

        {
            // Redeem GRAI for RETH
            (address firstRedemptionHint, uint256 partialRedemptionHintNewICR, uint256 truncatedGraiAmount ) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getRedemptionHints(
                MAINNET_RETH,
                15399891878336491376658,
                1790256288509586410169, // price feed value
                0
            );
            uint256 size = ISortedVessels(MAINNET_SORTED_VESSELS).getSize(MAINNET_RETH);
            (address hintAddress, ,) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getApproxHint(MAINNET_RETH, partialRedemptionHintNewICR, size, 1337);
            (address upperHint, address lowerHint) = ISortedVessels(MAINNET_SORTED_VESSELS).findInsertPosition(MAINNET_RETH, partialRedemptionHintNewICR, hintAddress, hintAddress);
            GravitaRedeem.Params memory params = GravitaRedeem.Params(MAINNET_RETH, truncatedGraiAmount, upperHint, lowerHint, firstRedemptionHint, partialRedemptionHintNewICR, 0, 1e18);
            callData[2] = abi.encode(params);        
            actionIds[2] = 1;
        }

        {
            SendToken.Params memory sendParams =
                SendToken.Params(MAINNET_RETH, address(flashUniV3), 850e16 + Math.mulDiv(850e16, 500, 1000000) );
            callData[3] = abi.encode(sendParams);
            actionIds[3] = 5;
        }


        uint256 oldBalance = IERC20(MAINNET_RETH).balanceOf(user);
        vm.prank(user);

        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));

        assertEq(response.length, 4);
        assertGt(IERC20(MAINNET_RETH).balanceOf(user) + IERC20(MAINNET_RETH).balanceOf(proxyAddress), oldBalance);
    }
}
