// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquityHelpers} from "./LiquityHelpers.t.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {LiquityOpen} from "src/actions/liquity/LiquityOpen.sol";
import {ITroveManager} from "src/actions/liquity/Interfaces/ITroveManager.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";
import {Unwrap} from "src/actions/utils/Unwrap.sol";
import {Wrap} from "src/actions/utils/Wrap.sol";
import {FlashUniV3} from "src/actions/flashloan/FlashUniV3.sol";
import {UniswapV3SwapExactInput} from "src/actions/exchange/UniswapV3SwapExactInput.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract LiquityFlashOpenTest is LiquityHelpers {
    uint256 _mainnetFork;

    LiquityOpen liquityOpen;
    FlashUniV3 flashUniV3;

    function setUp() public {
        _mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(_mainnetFork);
        vm.rollFork(17814506);

        _deployActionExecutorAndProxy();
        liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        flashUniV3 = new FlashUniV3(MAINNET_UNISWAP_FACTORY, address(actionExecutor), address(petalexProxy));
        deal(user, 1000000e18);
    }

    function _deploySubActions() internal {
        actionExecutor.setActionIdToAddress(3, address(flashUniV3));
        actionExecutor.setActionIdToAddress(1, address(liquityOpen));
        PullToken pullToken = new PullToken();
        actionExecutor.setActionIdToAddress(2, address(pullToken));

        UniswapV3SwapExactInput exchange = new UniswapV3SwapExactInput(MAINNET_SWAP_ROUTER);
        actionExecutor.setActionIdToAddress(4, address(exchange));
        SendToken sendToken = new SendToken();
        actionExecutor.setActionIdToAddress(5, address(sendToken));
        Unwrap unwrap = new Unwrap(MAINNET_WETH);
        actionExecutor.setActionIdToAddress(6, address(unwrap));
        Wrap wrap = new Wrap(MAINNET_WETH);
        actionExecutor.setActionIdToAddress(7, address(wrap));
    }

    // This also tests that eth gets sent correctly to the proxy address when flash loaning
    function test_OpenFlashTroveOnMaximumLeverage() public {
        vm.selectFork(_mainnetFork);
        _deploySubActions();

        uint256 tokenId = mintNFT(user);
        address proxyAddress = IPetalexNFT(address(petalexProxy)).getProxyAddressForToken(tokenId);

        bytes[] memory callData = new bytes[](6);
        uint8[] memory actionIds = new uint8[](6);
        uint256 col = 10e18;
        uint256 debt = 16000e18;
        uint256 startAmount = 20e17;
        {
            (address prevId, address nextId) = _getHints(col, debt);
            LiquityOpen.Params memory params = LiquityOpen.Params(1e18, col, debt, prevId, nextId);

            address pool = _getUniswapV3PoolAddress(MAINNET_WETH, MAINNET_USDC, 3000);
            address token0 = IUniswapV3Pool(pool).token0();
            address token1 = IUniswapV3Pool(pool).token1();

            FlashUniV3.FlashParams memory flashParams = FlashUniV3.FlashParams(
                token0, token1, pool, token0 == MAINNET_WETH ? 10e18 : 0, token1 == MAINNET_WETH ? 10e18 : 0
            );
            
            UniswapV3SwapExactInput.Params memory swapParams = UniswapV3SwapExactInput.Params(
                MAINNET_LIQUITY_LUSD,
                debt,
                0,
                abi.encodePacked(MAINNET_LIQUITY_LUSD, uint24(500), MAINNET_USDC, uint24(500), MAINNET_WETH)
            );

            callData[0] = abi.encode(flashParams);
            callData[2] = abi.encode(params);
            callData[3] = abi.encode(swapParams);
        }

        {
            SendToken.Params memory sendParams =
                SendToken.Params(MAINNET_WETH, address(flashUniV3), 10e18 + Math.mulDiv(10e18, 3000, 1000000)); 
            Wrap.Params memory wrapParams = Wrap.Params(type(uint256).max);                
            Unwrap.Params memory unwrap = Unwrap.Params(type(uint256).max);

            callData[1] = abi.encode(unwrap);
            callData[4] = abi.encode(wrapParams);
            callData[5] = abi.encode(sendParams);
        }

        actionIds[2] = 1;
        actionIds[0] = 3;
        actionIds[3] = 4;            
        actionIds[5] = 5;
        
        actionIds[1] = 6;
        actionIds[4] = 7;

        {
            vm.prank(user);
            bytes32[] memory response =
                actionExecutor.executeActionList{ value: startAmount }(ActionExecutor.ActionList(callData, actionIds, tokenId));
            assertEq(response.length, 6);

            assertEq(ITroveManager(address(MAINNET_LIQUITY_TROVE_MANAGER)).getTroveStatus(proxyAddress), 1);
            assertApproxEqAbs(
                ITroveManager(address(MAINNET_LIQUITY_TROVE_MANAGER)).getTroveDebt(proxyAddress),
                debt + 200e18 + ((debt * 5) / 1000),
                1e16 // redemptions were happening at this block so fees were slightly higher
            );
            assertEq(ITroveManager(address(MAINNET_LIQUITY_TROVE_MANAGER)).getTroveColl(proxyAddress), col);
        }
    }
}
