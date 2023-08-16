// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBorrowerOperations} from "./interfaces/IBorrowerOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ActionBase} from "../ActionBase.sol";

contract LiquityAdjust is ActionBase {
    struct Params {
        uint256 maxFee;
        uint256 collateralDeposit;
        uint256 collateralWithdrawal;
        uint256 debtChange;
        bool isDebtIncrease;
        address upperHint;
        address lowerHint;
    }

    IBorrowerOperations private immutable _liquityBorrowerOperations;
    address private immutable _lusd;

    constructor(address liquityBorrowerOperations, address lusd) {
        _liquityBorrowerOperations = IBorrowerOperations(liquityBorrowerOperations);
        _lusd = lusd;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        if (!params.isDebtIncrease && params.debtChange > 0) {
            IERC20(_lusd).approve(address(_liquityBorrowerOperations), params.debtChange);
        }

        _liquityBorrowerOperations.adjustTrove{value: params.collateralDeposit}(
            params.maxFee,
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
