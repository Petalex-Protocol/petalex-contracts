// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquityHelpers} from "./LiquityHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {LiquityRedeem} from "src/actions/liquity/LiquityRedeem.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ITroveManager} from "src/actions/liquity/Interfaces/ITroveManager.sol";
import {IPriceFeed} from "src/actions/liquity/Interfaces/IPriceFeed.sol";
import {ISortedTroves} from "src/actions/liquity/Interfaces/ISortedTroves.sol";
import {IHintHelpers} from "src/actions/liquity/Interfaces/IHintHelpers.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquityRedeemTest is LiquityHelpers {
    uint256 _mainnetFork;

    LiquityRedeem gravitaRedeem;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        _deployActionExecutorAndProxy();
        gravitaRedeem = new LiquityRedeem(MAINNET_LIQUITY_TROVE_MANAGER, MAINNET_LIQUITY_LUSD);
    }

    function _getWethSpotPrice() internal view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(MAINNET_USDC_ETH_POOL);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = 10**12 / (uint256(sqrtPriceX96) / 2**96)**2;
        return price * 1e18;
    }

    function test_RedeemLusd() public {
        vm.selectFork(_mainnetFork);
        _deployActionExecutorAndProxy();
        actionExecutor.setActionIdToAddress(1, address(gravitaRedeem));
        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);
        bytes[] memory callData = new bytes[](1);
        uint8[] memory actionIds = new uint8[](1);
        uint256 debt = 50_000e18;
        uint256 price = IPriceFeed(MAINNET_LIQUITY_PRICE_FEED).fetchPrice();
        {
            (address firstRedemptionHint, uint256 partialRedemptionHintNewICR, uint256 truncatedLUSDamount ) = IHintHelpers(MAINNET_LIQUITY_HINT_HELPERS).getRedemptionHints(
                debt,
                price,
                0
            );        
            uint256 size = ISortedTroves(MAINNET_LIQUITY_SORTED_TROVES).getSize();
            (address hintAddress, ,) = IHintHelpers(MAINNET_LIQUITY_HINT_HELPERS).getApproxHint(partialRedemptionHintNewICR, size, 1337);
            (address upperHint, address lowerHint) = ISortedTroves(MAINNET_LIQUITY_SORTED_TROVES).findInsertPosition(partialRedemptionHintNewICR, hintAddress, hintAddress);
            LiquityRedeem.Params memory params = LiquityRedeem.Params(truncatedLUSDamount, upperHint, lowerHint, firstRedemptionHint, partialRedemptionHintNewICR, 0, 1e18);
            callData[0] = abi.encode(params);        
            actionIds[0] = 1;
        }

        deal(MAINNET_LIQUITY_LUSD, proxyAddress, debt);

        vm.prank(user);
        bytes32[] memory response =
            actionExecutor.executeActionList(ActionExecutor.ActionList(callData, actionIds, tokenId));
        assertEq(response.length, 1);
        assertEq(response[0], bytes32(debt));
        assertApproxEqAbs(address(proxyAddress).balance * price / 1e18, debt, 3_000e17);
    }
}
