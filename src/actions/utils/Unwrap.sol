// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IWETH} from "../../interfaces/IWETH.sol";
import {ActionBase} from "../ActionBase.sol";

/// @title Action that unwraps native chain token
contract Unwrap is ActionBase {

    struct Params {
        uint256 amount;
    }

    IWETH private immutable _weth;

    constructor(address weth) {
        _weth = IWETH(weth);
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        require(params.amount > 0, "Amount can't be 0");

        _weth.withdraw(params.amount);
        return bytes32(params.amount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
