// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {DSProxy} from "./DSProxy.sol";
import {DSAuthority} from "./DSAuthority.sol";
import {DSProxyCache} from "./DSProxyCache.sol";

// DSProxyFactory
// This factory deploys new proxy instances through build()
// Deployed proxy addresses are logged
contract DSProxyFactory {
    event Created(address indexed sender, address indexed owner, address proxy, address cache);

    mapping(address => bool) public isProxy;

    DSProxyCache public cache = new DSProxyCache();
    DSAuthority public authority;

    constructor(address authority_) {
        authority = DSAuthority(authority_);
    }

    // deploys a new proxy instance
    // sets owner of proxy to caller
    function build() public returns (DSProxy proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy
    function build(address owner) public returns (DSProxy proxy) {
        proxy = new DSProxy(address(cache), owner, address(authority));
        emit Created(msg.sender, owner, address(proxy), address(cache));
        isProxy[address(proxy)] = true;
    }
}
