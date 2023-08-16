// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBorrowerOperations} from "./interfaces/IBorrowerOperations.sol";
import {ActionBase} from "../ActionBase.sol";

contract LiquityClose is ActionBase {
    IBorrowerOperations private immutable _liquityBorrowerOperations;

    constructor(address liquityBorrowerOperations) {
        _liquityBorrowerOperations = IBorrowerOperations(liquityBorrowerOperations);
    }

    function executeAction(bytes memory) public payable virtual override returns (bytes32) {
        _liquityBorrowerOperations.closeTrove();
        return bytes32("OK");
    }
}
