// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {PetalexNFT} from "../src/PetalexNFT.sol";
import {UUPSProxy} from "../src/Proxy.sol";

contract DeployExample is Script {
    UUPSProxy public proxy;

    PetalexNFT public impl;
    PetalexNFT public impl2; // should be petalexnftv2 or something

    function run() public {
        // private key for deployment
        uint256 pk = vm.envUint("PRIVATE_KEY");
        console.log("Deploying contracts with address", vm.addr(pk));

        vm.startBroadcast(pk);

        _deployInitialVersion();
        //_upradeImplementation();

        vm.stopBroadcast();

        console.log("Contracts deployed");
    }

    // Deploy logic and proxy contract
    function _deployInitialVersion() internal {
        // deploy logic contract
        impl = new PetalexNFT();
        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(impl), "");

        // initialize implementation contract
        (bool success,) = address(proxy).call(abi.encodeWithSignature("initialize(address)", address(0)));
        require(success, "Initialization failed");
    }

    // Upgrade logic contract
    function _upradeImplementation() internal {
        // deploy new logic contract
        impl2 = new PetalexNFT();
        // update proxy to new implementation contract
        (bool success,) = address(proxy).call(abi.encodeWithSignature("upgradeTo(address)", address(impl2)));
        if (!success) {
            console.log("Upgrade failed");
        }
    }
}
