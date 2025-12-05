// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {IUniversalRouter} from "./ext/IUniversalRouter.sol";
import {ITokiPoolToken} from "./ext/ITokiPoolToken.sol";

/// @notice Shared base for Napier fuses that route through the universal router.
/// @dev Centralizes versioning, market configuration, and common errors/helpers.
abstract contract NapierUniversalRouterFuse is IFuseCommon {
    /// @notice Version of this contract for tracking
    address public immutable VERSION;
    /// @notice Market ID this fuse is associated with
    uint256 public immutable MARKET_ID;
    /// @notice Napier V2 universal router
    IUniversalRouter public immutable ROUTER;

    /// @notice Error thrown when an invalid market ID is provided
    error NapierFuseIInvalidMarketId();
    /// @notice Error thrown when an invalid router address is provided
    error NapierFuseIInvalidRouter();
    /// @notice Error thrown when an invalid token or substrate is provided
    error NapierFuseIInvalidToken();
    /// @notice Error thrown when the execution returns fewer assets than expected
    error NapierFuseIInsufficientOutput();

    function _getPoolKey(ITokiPoolToken pool) internal view returns (PoolKey memory) {
        return pool.i_poolKey();
    }
}
