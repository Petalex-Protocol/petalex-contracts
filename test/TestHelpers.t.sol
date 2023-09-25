// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IVesselManager} from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import {IVesselManagerOperations} from "Gravita-SmartContracts/contracts/Interfaces/IVesselManagerOperations.sol";
import {ISortedVessels} from "Gravita-SmartContracts/contracts/Interfaces/ISortedVessels.sol";
import {IAdminContract} from "Gravita-SmartContracts/contracts/Interfaces/IAdminContract.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolAddress} from "src/libraries/PoolAddress.sol";
import {DSAuthority} from "src/DS/DSAuthority.sol";
import {DSProxyFactory} from "src/DS/DSProxyFactory.sol";
import {UUPSProxy} from "src/Proxy.sol";
import {PetalexNFT} from "src/PetalexNFT.sol";
import {IPetalexNFT} from "src/interfaces/IPetalexNFT.sol";
import {ActionExecutor} from "src/ActionExecutor.sol";
import {ActionRegistry} from "src/actions/ActionRegistry.sol";

contract TestHelpers is Test {
    string public MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    address public constant MAINNET_BLUSD = address(0xB9D7DdDca9a4AC480991865EfEf82E01273F79C3);
    address public constant MAINNET_GRAI = address(0x15f74458aE0bFdAA1a96CA1aa779D715Cc1Eefe4);
    address public constant MAINNET_USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant MAINNET_SORTED_VESSELS = address(0xF31D88232F36098096d1eB69f0de48B53a1d18Ce);
    address public constant MAINNET_BORROWER_OPERATIONS = address(0x2bCA0300c2aa65de6F19c2d241B54a445C9990E2);
    address public constant MAINNET_SWAP_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public constant MAINNET_UNISWAP_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public constant MAINNET_VESSEL_MANAGER = address(0xdB5DAcB1DFbe16326C3656a88017f0cB4ece0977);
    address public constant MAINNET_VESSEL_MANAGER_OPERATIONS = address(0xc49B737fa56f9142974a54F6C66055468eC631d0);
    address public constant MAINNET_ADMIN_CONTRACT = address(0xf7Cc67326F9A1D057c1e4b110eF6c680B13a1f53);
    address public constant MAINNET_BLUSD_CURVE_POOL = address(0x74ED5d42203806c8CDCf2F04Ca5F60DC777b901c);
    address public constant MAINNET_GRAI_CURVE_POOL = address(0x3175f54A354C83e8ADe950c14FA3e32fc794c0Dc);
    address public constant MAINNET_3POOL = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address public constant MAINNET_3CRV = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public constant MAINNET_LUSD_3POOL = address(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    address public constant MAINNET_LUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    address public constant MAINNET_WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant MAINNET_PERMIT2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address public constant MAINNET_GRAI_USDC_POOL = address(0x5db3D38bD40C862BA1fDB2286c32A62ab954d36D);
    address public constant MAINNET_USDC_ETH_POOL = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    address public constant MAINNET_STFRXETH = address(0xac3E018457B222d93114458476f3E3416Abbe38F);
    address public constant MAINNET_RETH = address(0xae78736Cd615f374D3085123A210448E74Fc6393);
    address public constant MAINNET_PRICE_FEED = address(0x89F1ecCF2644902344db02788A790551Bb070351);

    string public constant GET_PROXY_ADDRESS_FOR_TOKEN_SIGNATURE = "getProxyAddressForToken(uint256)";
    string public constant MINT_BATCH_SIGNATURE = "mintBatch(address,uint256[],bytes)";
    string public constant BALANCE_OF_SIGNATURE = "balanceOf(address,uint256)";
    string public constant OWNED_TOKENS_SIGNATURE = "getOwnedTokens(address)";

    bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 public constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    uint256 public userKey = 1;
    address public user = vm.addr(userKey);

    uint256[3][4] _swapParams = [[0, 2, 2], [1, 0, 8], [1, 0, 7], [1, 0, 3]];

    UUPSProxy public petalexProxy;
    ActionExecutor public actionExecutor;
    ActionRegistry public actionRegistry;
    DSAuthority public authority;

    function _getHints(uint256 col, uint256 debt) internal returns (address, address) {
        uint256 nicr = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).computeNominalCR(col, debt);
        uint256 size = ISortedVessels(MAINNET_SORTED_VESSELS).getSize(MAINNET_BLUSD);
        (address hintAddress,,) =
            IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getApproxHint(MAINNET_BLUSD, nicr, size, 1337);
        (address prevId, address nextId) =
            ISortedVessels(MAINNET_SORTED_VESSELS).findInsertPosition(MAINNET_BLUSD, nicr, hintAddress, hintAddress);
        return (prevId, nextId);
    }

    function _getCurveSwapHash(uint256 amount) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "exchange_multiple(address[9],uint256[3][4],uint256,uint256)",
            [
                MAINNET_GRAI,
                MAINNET_GRAI_CURVE_POOL,
                MAINNET_USDC,
                MAINNET_3POOL,
                MAINNET_3CRV,
                MAINNET_LUSD_3POOL,
                MAINNET_LUSD_3POOL,
                MAINNET_BLUSD_CURVE_POOL,
                MAINNET_BLUSD
            ],
            _swapParams,
            amount,
            0
        );
    }

    function _getUniswapSwapPath() internal pure returns (bytes memory) {
        return abi.encodePacked(
            MAINNET_GRAI, uint24(500), MAINNET_USDC, uint24(500), MAINNET_LUSD, uint24(500), MAINNET_BLUSD
        );
    }

    function _getUniswapV3PoolAddress(address token0, address token1, uint24 fee) internal pure returns (address) {
        IUniswapV3Pool pool = IUniswapV3Pool(
            PoolAddress.computeAddress(MAINNET_UNISWAP_FACTORY, PoolAddress.getPoolKey(token0, token1, fee))
        );
        return address(pool);
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    // Generate a signature for a permit message.
    function _signPermit(ISignatureTransfer.PermitTransferFrom memory permit, address spender, uint256 signerKey)
        internal
        view
        returns (bytes memory sig)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, _getEIP712Hash(permit, spender));
        return abi.encodePacked(r, s, v);
    }

    // Compute the EIP712 hash of the permit object.
    // Normally this would be implemented off-chain.
    function _getEIP712Hash(ISignatureTransfer.PermitTransferFrom memory permit, address spender)
        internal
        view
        returns (bytes32 h)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                ISignatureTransfer(MAINNET_PERMIT2).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_FROM_TYPEHASH,
                        keccak256(
                            abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
                        ),
                        spender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );
    }

    function _deployProxyContracts() internal {
        authority = new DSAuthority(address(this));
        DSProxyFactory proxyFactory = new DSProxyFactory(address(authority));
        PetalexNFT petalexNFT = new PetalexNFT();
        petalexProxy = new UUPSProxy(address(petalexNFT), "");
        (bool success,) =
            address(petalexProxy).call(abi.encodeWithSignature("initialize(address)", address(proxyFactory)));
        assertEq(success, true);
    }

    function _deployActions() internal {
        actionRegistry = new ActionRegistry(address(this));
        actionExecutor =
            new ActionExecutor(address(petalexProxy), address(authority), address(actionRegistry), address(this));
        actionRegistry.setActionExecutor(address(actionExecutor));
        authority.setAuthority(address(actionExecutor), true);
        IPetalexNFT(address(petalexProxy)).setActionExecutor(address(actionExecutor));
    }
}
