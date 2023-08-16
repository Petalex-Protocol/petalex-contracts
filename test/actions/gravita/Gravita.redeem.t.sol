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
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";
import {FlashUniV3} from "src/actions/flashloan/FlashUniV3.sol";
import {UniswapV3SwapExactInput} from "src/actions/exchange/UniswapV3SwapExactInput.sol";

contract GravitaRedeemTest is ActionTestHelpers {
    uint256 _mainnetFork;

    GravitaRedeem gravitaRedeem;
    GravitaOpen gravitaOpen;
    FlashUniV3 flashUniV3;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        _deployActionExecutorAndProxy();
        gravitaRedeem = new GravitaRedeem(MAINNET_VESSEL_MANAGER_OPERATIONS, MAINNET_GRAI);                
        gravitaOpen = new GravitaOpen(MAINNET_BORROWER_OPERATIONS);
        flashUniV3 = new FlashUniV3(MAINNET_UNISWAP_FACTORY, address(actionExecutor), address(petalexProxy));
        deal(MAINNET_WETH, user, 1_000_000e18);        
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

    function _getWethSpotPrice() internal view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(MAINNET_USDC_ETH_POOL);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = 10**12 / (uint256(sqrtPriceX96) / 2**96)**2;
        return price * 1e18;
    }

    function test_RedeemGrai() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaRedeem));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);
        bytes[] memory callData = new bytes[](1);
        uint8[] memory actionIds = new uint8[](1);
        uint256 debt = 50_000e18;
        uint256 price = _getWethSpotPrice();
        {
            (address firstRedemptionHint, uint256 partialRedemptionHintNewICR, ) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getRedemptionHints(
                MAINNET_WETH,
                debt,
                price,
                0
            );        
            uint256 size = ISortedVessels(MAINNET_SORTED_VESSELS).getSize(MAINNET_WETH);
            (address hintAddress, ,) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getApproxHint(MAINNET_WETH, 11e17, size, 1337);
            (address upperHint, address lowerHint) = ISortedVessels(MAINNET_SORTED_VESSELS).findInsertPosition(MAINNET_WETH, partialRedemptionHintNewICR, hintAddress, hintAddress);
            GravitaRedeem.Params memory params = GravitaRedeem.Params(MAINNET_WETH, debt, upperHint, lowerHint, firstRedemptionHint, partialRedemptionHintNewICR, 0, 1e18);
            callData[0] = abi.encode(params);        
            actionIds[0] = 1;
        }

        deal(MAINNET_GRAI, proxyAddress, debt);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(debt));
        assertApproxEqAbs(IERC20(MAINNET_WETH).balanceOf(proxyAddress) * price / 1e18, debt, 3_000e18);
        console.log(debt - (IERC20(MAINNET_WETH).balanceOf(proxyAddress) * price / 1e18));
    }
}
