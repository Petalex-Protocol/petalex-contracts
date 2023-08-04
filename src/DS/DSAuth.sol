// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {DSAuthority} from "./DSAuthority.sol";

abstract contract DSAuth {
    event LogSetOwner(address indexed owner);

    address public owner;
    DSAuthority public authority;

    function setOwner(address owner_) public auth {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    modifier auth() {
        require(isAuthorized(msg.sender), "NA");
        _;
    }

    function isAuthorized(address src) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority.isAuthorized(src)) {
            return true;
        }
        return false;
    }
}
