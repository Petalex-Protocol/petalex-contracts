// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITroveManager} from "src/actions/liquity/Interfaces/ITroveManager.sol";
import {ISortedTroves} from "src/actions/liquity/Interfaces/ISortedTroves.sol";
import {IHintHelpers} from "src/actions/liquity/Interfaces/IHintHelpers.sol";
import {ActionTestHelpers} from "../ActionTestHelpers.t.sol";

contract LiquityHelpers is ActionTestHelpers {
    address public constant MAINNET_LIQUITY_BORROWER_OPERATIONS = address(0x24179CD81c9e782A4096035f7eC97fB8B783e007);
    address public constant MAINNET_LIQUITY_SORTED_TROVES = address(0x8FdD3fbFEb32b28fb73555518f8b361bCeA741A6);
    address public constant MAINNET_LIQUITY_TROVE_MANAGER = address(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
    address public constant MAINNET_LIQUITY_LUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    address public constant MAINNET_LIQUITY_HINT_HELPERS = address(0xE84251b93D9524E0d2e621Ba7dc7cb3579F997C0);
    address public constant MAINNET_LIQUITY_PRICE_FEED = address(0x4c517D4e2C851CA76d7eC94B805269Df0f2201De);

    function _getLiquityHints(uint256 col, uint256 debt) internal view returns (address, address) {
        uint256 nicr = IHintHelpers(MAINNET_LIQUITY_HINT_HELPERS).computeNominalCR(col, debt);
        uint256 size = ISortedTroves(MAINNET_LIQUITY_SORTED_TROVES).getSize();
        (address hintAddress,,) =
            IHintHelpers(MAINNET_LIQUITY_HINT_HELPERS).getApproxHint(nicr, size, 1337); // should be size * 15 but calculating onchain is unnecessary
        (address prevId, address nextId) =
            ISortedTroves(MAINNET_LIQUITY_SORTED_TROVES).findInsertPosition(nicr, hintAddress, hintAddress);
        return (prevId, nextId);
    }
}
