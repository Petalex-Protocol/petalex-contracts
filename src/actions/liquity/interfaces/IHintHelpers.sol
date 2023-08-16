// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHintHelpers {
    function getApproxHint(uint _CR, uint _numTrials, uint _inputRandomSeed) external view returns (address hintAddress, uint diff, uint latestRandomSeed);
    function getRedemptionHints(
        uint _LUSDamount, 
        uint _price,
        uint _maxIterations
    ) external view returns (
            address firstRedemptionHint,
            uint partialRedemptionHintNICR,
            uint truncatedLUSDamount
        );
    function computeNominalCR(uint _coll, uint _debt) external pure returns (uint);
}
