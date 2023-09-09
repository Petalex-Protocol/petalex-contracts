// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract MainnetAddresses is Script {
    address public constant MAINNET_WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant MAINNET_GRAI = address(0x15f74458aE0bFdAA1a96CA1aa779D715Cc1Eefe4);
    address public constant MAINNET_GRAVITA_SORTED_VESSELS = address(0xF31D88232F36098096d1eB69f0de48B53a1d18Ce);
    address public constant MAINNET_GRAVITA_BORROWER_OPERATIONS = address(0x2bCA0300c2aa65de6F19c2d241B54a445C9990E2);
    address public constant MAINNET_GRAVITA_VESSEL_MANAGER = address(0xdB5DAcB1DFbe16326C3656a88017f0cB4ece0977);
    address public constant MAINNET_GRAVITA_VESSEL_MANAGER_OPERATIONS = address(0xc49B737fa56f9142974a54F6C66055468eC631d0);
    address public constant MAINNET_GRAVITA_ADMIN_CONTRACT = address(0xf7Cc67326F9A1D057c1e4b110eF6c680B13a1f53);

    address public constant MAINNET_LIQUITY_BORROWER_OPERATIONS = address(0x24179CD81c9e782A4096035f7eC97fB8B783e007);
    address public constant MAINNET_LIQUITY_SORTED_TROVES = address(0x8FdD3fbFEb32b28fb73555518f8b361bCeA741A6);
    address public constant MAINNET_LIQUITY_TROVE_MANAGER = address(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
    address public constant MAINNET_LIQUITY_LUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    address public constant MAINNET_LIQUITY_HINT_HELPERS = address(0xE84251b93D9524E0d2e621Ba7dc7cb3579F997C0);
    address public constant MAINNET_LIQUITY_PRICE_FEED = address(0x4c517D4e2C851CA76d7eC94B805269Df0f2201De);

    address public constant MAINNET_SWAP_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public constant MAINNET_UNISWAP_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public constant MAINNET_PERMIT2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
}