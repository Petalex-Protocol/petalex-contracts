// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {PetalexNFT} from "src/PetalexNFT.sol";
import {UUPSProxy} from "src/Proxy.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";

import {ActionExecutor} from "src/ActionExecutor.sol";
import {ActionRegistry} from "src/actions/ActionRegistry.sol";

import {DSAuthority} from "src/DS/DSAuthority.sol";
import {DSProxyFactory} from "src/DS/DSProxyFactory.sol";

import {UniswapV3SwapExactInput} from "src/actions/exchange/UniswapV3SwapExactInput.sol";
import {FlashUniV3} from "src/actions/flashloan/FlashUniV3.sol";
import {GravitaOpen} from "src/actions/gravita/GravitaOpen.sol";
import {GravitaAdjust} from "src/actions/gravita/GravitaAdjust.sol";
import {GravitaClose} from "src/actions/gravita/GravitaClose.sol";
import {GravitaRedeem} from "src/actions/gravita/GravitaRedeem.sol";
import {LiquityAdjust} from "src/actions/liquity/LiquityAdjust.sol";
import {LiquityOpen} from "src/actions/liquity/LiquityOpen.sol";
import {LiquityClose} from "src/actions/liquity/LiquityClose.sol";
import {LiquityRedeem} from "src/actions/liquity/LiquityRedeem.sol";
import {PullToken} from "src/actions/utils/PullToken.sol";
import {SendToken} from "src/actions/utils/SendToken.sol";
import {PermitPullToken} from "src/actions/utils/PermitPullToken.sol";

import "./helpers/MainnetAddresses.sol";

contract DeployPetalexInitial is MainnetAddresses {
    DSAuthority public dsAuthority;
    DSProxyFactory public dsProxyFactory;
    UUPSProxy public proxy;

    PetalexNFT public petalexNFT;

    ActionExecutor public actionExecutor;
    ActionRegistry public actionRegistry;

    function run() public {
        // private key for deployment
        uint256 pk = vm.envUint("PRIVATE_KEY");
        console.log("Deploying contracts with address", vm.addr(pk));

        vm.startBroadcast(pk);

        _deployDSProxyFactory(vm.addr(pk));
        _deployInitialVersion();
        _deployActions(vm.addr(pk));

        vm.stopBroadcast();

        console.log("Contracts deployed");
    }

    function _deployDSProxyFactory(address owner) internal {
        dsAuthority = new DSAuthority(owner);
        dsProxyFactory = new DSProxyFactory(address(dsAuthority));
    }

    // Deploy logic and proxy contract
    function _deployInitialVersion() internal {
        // deploy logic contract
        petalexNFT = new PetalexNFT();
        // deploy proxy contract and point it to implementation
        proxy = new UUPSProxy(address(petalexNFT), "");

        // initialize implementation contract
        (bool success,) = address(proxy).call(abi.encodeWithSignature("initialize(address)", address(dsProxyFactory)));
        require(success, "Initialization failed");
    }

    function _deployActions(address owner) internal {
        actionRegistry = new ActionRegistry(owner);
        actionExecutor =
            new ActionExecutor(address(proxy), address(dsAuthority), address(actionRegistry), owner);
        actionRegistry.setActionExecutor(address(actionExecutor));
        dsAuthority.setAuthority(address(actionExecutor), true);
        IPetalexNFT(address(proxy)).setActionExecutor(address(actionExecutor));

        // EXCHANGE
        UniswapV3SwapExactInput exchange = new UniswapV3SwapExactInput(MAINNET_SWAP_ROUTER);

        // FLASH LOAN
        FlashUniV3 flashUniV3 = new FlashUniV3(MAINNET_UNISWAP_FACTORY, address(actionExecutor), address(proxy));
        
        // GRAVITA
        GravitaAdjust gravitaAdjust = new GravitaAdjust(MAINNET_GRAVITA_BORROWER_OPERATIONS, MAINNET_GRAI);
        GravitaOpen gravitaOpen = new GravitaOpen(MAINNET_GRAVITA_BORROWER_OPERATIONS);
        GravitaClose gravitaClose = new GravitaClose(MAINNET_GRAVITA_BORROWER_OPERATIONS, 1);
        GravitaRedeem gravitaRedeem = new GravitaRedeem(MAINNET_GRAVITA_VESSEL_MANAGER_OPERATIONS, MAINNET_GRAI);

        // LIQUITY
        LiquityAdjust liquityAdjust = new LiquityAdjust(MAINNET_LIQUITY_BORROWER_OPERATIONS, MAINNET_LIQUITY_LUSD);
        LiquityOpen liquityOpen = new LiquityOpen(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        LiquityClose liquityClose = new LiquityClose(MAINNET_LIQUITY_BORROWER_OPERATIONS);
        LiquityRedeem liquityRedeem = new LiquityRedeem(MAINNET_LIQUITY_TROVE_MANAGER, MAINNET_LIQUITY_LUSD);

        // UTILS
        PullToken pullToken = new PullToken();
        SendToken sendToken = new SendToken();
        PermitPullToken permitPullToken = new PermitPullToken(MAINNET_PERMIT2);

        // Set action ids
        actionExecutor.setActionIdToAddress(1, address(sendToken));
        actionExecutor.setActionIdToAddress(2, address(flashUniV3));
        actionExecutor.setActionIdToAddress(3, address(pullToken));
        actionExecutor.setActionIdToAddress(4, address(exchange));
        actionExecutor.setActionIdToAddress(5, address(gravitaOpen));
        actionExecutor.setActionIdToAddress(6, address(gravitaAdjust));
        actionExecutor.setActionIdToAddress(7, address(gravitaClose));
        actionExecutor.setActionIdToAddress(8, address(gravitaRedeem));
        actionExecutor.setActionIdToAddress(9, address(liquityOpen));
        actionExecutor.setActionIdToAddress(10, address(liquityAdjust));
        actionExecutor.setActionIdToAddress(11, address(liquityClose));
        actionExecutor.setActionIdToAddress(12, address(liquityRedeem));
        actionExecutor.setActionIdToAddress(13, address(permitPullToken));
    }
}
