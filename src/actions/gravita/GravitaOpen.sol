// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBorrowerOperations} from "Gravita-SmartContracts/contracts/interfaces/IBorrowerOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ActionBase} from "../ActionBase.sol";

contract GravitaOpen is ActionBase {
    struct Params {
        address collateral;
        uint256 collateralAmount;
        uint256 debtAmount;
        address upperHint;
        address lowerHint;
    }

    IBorrowerOperations private immutable _gravitaBorrowerOperations;

    constructor(address gravitaBorrowerOperations) {
        _gravitaBorrowerOperations = IBorrowerOperations(gravitaBorrowerOperations);
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        IERC20(params.collateral).approve(address(_gravitaBorrowerOperations), params.collateralAmount);
        _gravitaBorrowerOperations.openVessel(
            params.collateral, params.collateralAmount, params.debtAmount, params.upperHint, params.lowerHint
        );
        return bytes32(params.debtAmount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
