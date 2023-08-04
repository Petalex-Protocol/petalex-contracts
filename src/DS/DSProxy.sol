// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {DSAuth} from "./DSAuth.sol";
import {DSAuthority} from "./DSAuthority.sol";
import {DSProxyCache} from "./DSProxyCache.sol";
import {IDSProxy} from "./IDSProxy.sol";

// DSProxy
// Allows code execution using a persistant identity This can be very
// useful to execute a sequence of atomic actions. Since the owner of
// the proxy can be changed, this allows for dynamic ownership models
// i.e. a multisig
contract DSProxy is DSAuth, IDSProxy {
    DSProxyCache public cache; // global cache for contracts

    constructor(address _cacheAddr, address _owner, address _authority) {
        require(_setCache(_cacheAddr), "SCA");
        owner = _owner;
        authority = DSAuthority(_authority);
    }

    fallback() external payable {}

    receive() external payable {}

    // use the proxy to execute calldata _data on contract _code
    function execute(bytes memory _code, bytes memory _data)
        public
        payable
        override
        returns (address target, bytes32 response)
    {
        target = cache.read(_code);
        if (target == address(0x0)) {
            // deploy contract & store its address in cache
            target = cache.write(_code);
        }

        response = execute(target, _data);
    }

    function execute(address _target, bytes memory _data) public payable override auth returns (bytes32 response) {
        require(_target != address(0x0), "0A");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()
            response := mload(0x40) // load delegatecall output
            returndatacopy(response, 0, size)
            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(response, size)
            }
            default { return(response, size) }
        }
    }

    //set new cache
    function setCache(address _cacheAddr) public auth returns (bool) {
        return _setCache(_cacheAddr);
    }

    function _setCache(address _cacheAddr) internal returns (bool) {
        require(_cacheAddr != address(0x0), "ICA"); // invalid cache address
        cache = DSProxyCache(_cacheAddr); // overwrite cache
        return true;
    }
}
