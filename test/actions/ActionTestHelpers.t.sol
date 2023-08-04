// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {TestHelpers} from "../TestHelpers.t.sol";

contract ActionTestHelpers is TestHelpers {
    function _deployActionExecutorAndProxy() internal {
        _deployProxyContracts();
        _deployActions();
    }

    function mintNFT(address addr) internal returns (uint256) {
        vm.prank(addr);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        bytes memory data = abi.encodePacked("0x");
        IPetalexNFT(address(petalexProxy)).mintBatch(user, ids, data);
        return ids[0];
    }
}
