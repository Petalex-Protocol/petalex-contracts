// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ActionBase} from "../ActionBase.sol";

/// @title Action that sends token from Proxy to a given address
contract SendToken is ActionBase {
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct Params {
        address token;
        address to;
        uint256 amount;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        require(params.amount > 0, "Amount can't be 0");
        require(params.to != address(0), "Can't send to 0 address");
        require(params.to != address(this), "Can't send to action address");

        if (params.token == ETH_ADDR) {
            if (params.amount == type(uint256).max) {
                params.amount = address(this).balance;
            }
            (bool success, ) = params.to.call{value: params.amount}("");
            require(success, "SendToken: Eth send fail");
        } else {
            if (params.amount == type(uint256).max) {
                params.amount = IERC20(params.token).balanceOf(address(this));
            }
            IERC20(params.token).safeTransfer(params.to, params.amount);
        }
        
        return bytes32(params.amount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
