// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3FlashCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolAddress} from "../../libraries/PoolAddress.sol";
import {ActionBase} from "../ActionBase.sol";
import {IPetalexNFT} from "../../interfaces/IPetalexNFT.sol";
import {IDSProxy} from "../../DS/IDSProxy.sol";

/// @title Action that flash loans token of a Uniswap V3 pool
contract FlashUniV3 is ActionBase, IUniswapV3FlashCallback {
    using SafeERC20 for IERC20;

    struct FlashParams {
        address token0;
        address token1;
        address pool;
        uint256 amount0;
        uint256 amount1;
    }

    struct Params {
        bytes[] callData;
        uint8[] actionIds;
        uint256 tokenId;
    }

    address private immutable _factory;
    address private immutable _actionExecutor;
    IPetalexNFT private immutable _nftProxy;

    bytes4 public constant CALLBACK_SELECTOR = bytes4(keccak256("executeActionsFromFL((bytes[],uint8[],uint256))"));

    constructor(address factory, address actionExecutor, address nftProxy) {
        _factory = factory;
        _actionExecutor = actionExecutor;
        _nftProxy = IPetalexNFT(nftProxy);
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        FlashParams memory flashParams = abi.decode(params.callData[0], (FlashParams));

        require(flashParams.amount0 > 0 || flashParams.amount1 > 0, "Amount can't be 0");
        require(flashParams.pool != address(0), "Can't flash from 0 address");

        IUniswapV3Pool(flashParams.pool).flash(
            address(this), flashParams.amount0, flashParams.amount1, abi.encode(params)
        );
        return bytes32(flashParams.amount0);
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata _data) external override {
        Params memory params = parseInputs(_data);
        FlashParams memory flashParams = abi.decode(params.callData[0], (FlashParams));

        IUniswapV3Pool pool = IUniswapV3Pool(
            PoolAddress.computeAddress(
                _factory,
                PoolAddress.getPoolKey(flashParams.token0, flashParams.token1, IUniswapV3Pool(msg.sender).fee())
            )
        );
        require(msg.sender == address(pool), "Invalid pool");

        address proxy = _nftProxy.getProxyAddressForToken(params.tokenId);

        IERC20(flashParams.token0).safeTransfer(proxy, flashParams.amount0);
        IERC20(flashParams.token1).safeTransfer(proxy, flashParams.amount1);

        IDSProxy(proxy).execute{value: address(this).balance}(
            payable(_actionExecutor), abi.encodeWithSelector(CALLBACK_SELECTOR, params)
        );

        if (fee0 > 0) {
            IERC20(flashParams.token0).safeTransfer(msg.sender, flashParams.amount0 + fee0);
        }
        if (fee1 > 0) {
            IERC20(flashParams.token1).safeTransfer(msg.sender, flashParams.amount1 + fee1);
        }
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }

    function actionType() public pure virtual override returns (ActionType) {
        return ActionType.FLASHLOAN;
    }
}
