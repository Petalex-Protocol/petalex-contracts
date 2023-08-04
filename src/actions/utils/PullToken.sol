// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ActionBase} from "../ActionBase.sol";

/// @title Action that sends token from Proxy to a given address
contract PullToken is ActionBase {
    using SafeERC20 for IERC20;

    struct Params {
        address token;
        address from;
        uint256 amount;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        require(params.amount > 0, "Amount can't be 0");
        require(params.from != address(0), "Can't pull from 0 address");
        require(params.from != address(this), "Can't pull from action address");

        IERC20(params.token).safeTransferFrom(params.from, address(this), params.amount);
        return bytes32(params.amount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
