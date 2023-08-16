// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITroveManager} from "./interfaces/ITroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ActionBase} from "../ActionBase.sol";

contract LiquityRedeem is ActionBase {
    struct Params {
        uint256 debtAmount;
        address upperHint;
        address lowerHint;
        address firstRedemptionHint;
        uint256 partialRedemptionHintNICR;
        uint256 maxIterations;
        uint256 maxFeePercentage;
    }

    ITroveManager private immutable _troveManager;
    address private immutable _lusd;

    constructor(address troveManager, address lusd) {
        _troveManager = ITroveManager(troveManager);
        _lusd = lusd;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        IERC20(_lusd).approve(address(_troveManager), params.debtAmount);
        _troveManager.redeemCollateral(
            params.debtAmount, params.firstRedemptionHint, params.upperHint, params.lowerHint, params.partialRedemptionHintNICR, params.maxIterations, params.maxFeePercentage
        );
        return bytes32(params.debtAmount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
