// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVesselManagerOperations} from "Gravita-SmartContracts/contracts/interfaces/IVesselManagerOperations.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ActionBase} from "../ActionBase.sol";

contract GravitaRedeem is ActionBase {
    struct Params {
        address collateral;
        uint256 debtAmount;
        address upperHint;
        address lowerHint;
        address firstRedemptionHint;
        uint256 partialRedemptionHintNICR;
        uint256 maxIterations;
        uint256 maxFeePercentage;
    }

    IVesselManagerOperations private immutable _vesselOperationsManager;
    address private immutable _grai;

    constructor(address vesselOperationsManager, address grai) {
        _vesselOperationsManager = IVesselManagerOperations(vesselOperationsManager);
        _grai = grai;
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        IERC20(_grai).approve(address(_vesselOperationsManager), params.debtAmount);
        _vesselOperationsManager.redeemCollateral(
            params.collateral, params.debtAmount, params.upperHint, params.lowerHint, params.firstRedemptionHint, params.partialRedemptionHintNICR, params.maxIterations, params.maxFeePercentage
        );
        return bytes32(params.debtAmount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
