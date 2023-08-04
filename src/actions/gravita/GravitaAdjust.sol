// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBorrowerOperations} from "Gravita-SmartContracts/contracts/interfaces/IBorrowerOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ActionBase} from "../ActionBase.sol";

contract GravitaAdjust is ActionBase {
    struct Params {
        address collateral;
        uint256 collateralDeposit;
        uint256 collateralWithdrawal;
        uint256 debtChange;
        bool isDebtIncrease;
        address upperHint;
        address lowerHint;
    }

    IBorrowerOperations private immutable _gravitaBorrowerOperations;
    address private immutable _grai;

    constructor(address gravitaBorrowerOperations, address grai) {
        _gravitaBorrowerOperations = IBorrowerOperations(gravitaBorrowerOperations);
        _grai = grai;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        if (params.collateralDeposit > 0) {
            IERC20(params.collateral).approve(address(_gravitaBorrowerOperations), params.collateralDeposit);
        }
        if (!params.isDebtIncrease && params.debtChange > 0) {
            IERC20(_grai).approve(address(_gravitaBorrowerOperations), params.debtChange);
        }

        _gravitaBorrowerOperations.adjustVessel(
            params.collateral,
            params.collateralDeposit,
            params.collateralWithdrawal,
            params.debtChange,
            params.isDebtIncrease,
            params.upperHint,
            params.lowerHint
        );
        return bytes32(params.debtChange);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
