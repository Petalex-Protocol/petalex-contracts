// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
import {ActionBase} from "../ActionBase.sol";

/// @title Action that sends token from Proxy to a given address using Permit2 (offchain signature allowance)
contract PermitPullToken is ActionBase {
    struct Params {
        address token;
        address from;
        uint256 amount;
        uint256 deadline;
        uint256 nonce;
        bytes signature;
    }

    ISignatureTransfer private immutable _permit2;

    constructor(address permit2) {
        _permit2 = ISignatureTransfer(permit2);
    }

    function executeAction(bytes memory _callData) public payable virtual override returns (bytes32) {
        Params memory params = parseInputs(_callData);

        require(params.amount > 0, "Amount can't be 0");
        require(params.from != address(0), "Can't pull from 0 address");
        require(params.from != address(this), "Can't pull from action address");
        require(params.deadline > block.timestamp, "Deadline passed");

        _permit2.permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({token: params.token, amount: params.amount}),
                nonce: params.nonce,
                deadline: params.deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: params.amount}),
            params.from,
            params.signature
        );

        return bytes32(params.amount);
    }

    function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
        params = abi.decode(_callData, (Params));
    }
}
