// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IDSProxy {
    function execute(bytes memory _code, bytes memory _data)
        external
        payable
        returns (address target, bytes32 response);

    function execute(address _target, bytes memory _data) external payable returns (bytes32 response);
}
