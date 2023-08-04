// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "@uniswap-v3-periphery/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ActionBase} from "../ActionBase.sol";

contract UniswapV3SwapExactInput is ActionBase {
    using SafeERC20 for IERC20;

    struct Params {
        address token;
        uint256 amount;
        uint256 amountOutMinimum;
        bytes path;
    }

    ISwapRouter private immutable _swapRouter;

    constructor(address swapRouter) {
        _swapRouter = ISwapRouter(swapRouter);
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        require(params.amount > 0, "Amount can't be 0");
        require(params.token != address(0), "Can't swap the 0 address");
        require(params.token != address(this), "Can't swap the action address");

        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: params.path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: params.amount,
            amountOutMinimum: params.amountOutMinimum
        });
        IERC20(params.token).safeIncreaseAllowance(address(_swapRouter), params.amount);
        uint256 received = _swapRouter.exactInput(swapParams);
        return bytes32(received);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
