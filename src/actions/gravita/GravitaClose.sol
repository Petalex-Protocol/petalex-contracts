// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBorrowerOperations} from "Gravita-SmartContracts/contracts/interfaces/IBorrowerOperations.sol";
import {ActionBase} from "../ActionBase.sol";

contract GravitaClose is ActionBase {
    struct Params {
        address collateral;
    }

    IBorrowerOperations private immutable _gravitaBorrowerOperations;

    constructor(address gravitaBorrowerOperations, uint8 actionRollWeight) {
        _gravitaBorrowerOperations = IBorrowerOperations(gravitaBorrowerOperations);
        _actionRollWeight = actionRollWeight;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        _gravitaBorrowerOperations.closeVessel(params.collateral);
        return bytes32(uint256(uint160(params.collateral)));
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
