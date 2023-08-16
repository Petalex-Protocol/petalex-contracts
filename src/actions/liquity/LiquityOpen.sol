// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBorrowerOperations} from "./interfaces/IBorrowerOperations.sol";
import {ActionBase} from "../ActionBase.sol";

contract LiquityOpen is ActionBase {
    struct Params {
        uint256 maxFee;
        uint256 collateralAmount;
        uint256 debtAmount;
        address upperHint;
        address lowerHint;
    }

    IBorrowerOperations private immutable _liquityBorrowerOperations;

    constructor(address liquityBorrowerOperations) {
        _liquityBorrowerOperations = IBorrowerOperations(liquityBorrowerOperations);
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        _liquityBorrowerOperations.openTrove{value: params.collateralAmount}(
            params.maxFee, params.debtAmount, params.upperHint, params.lowerHint
        );
        return bytes32(params.debtAmount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
