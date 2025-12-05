// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";

import {PoolKey, Currency} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {ITokiPoolToken} from "./ext/ITokiPoolToken.sol";
import {IPrincipalToken} from "./ext/IPrincipalToken.sol";
import {IUniversalRouter} from "./ext/IUniversalRouter.sol";
import {Commands} from "./utils/Commands.sol";
import {ApproximationParams} from "./ext/ApproximationParams.sol";
import {NapierUniversalRouterFuse} from "./NapierUniversalRouterFuse.sol";
import {IPermit2} from "../balancer/ext/IPermit2.sol";

/// @notice Fuse for swapping between underlying and YT through the Napier universal router with permit safety.
/// @dev Ensures substrate validation, slippage bounds, and zeroes Permit2 approvals after use.

/// @param tokenIn Asset to issue PT/YT with
/// @param amountIn Amount of the asset to issue PT/YT with
/// @param minimumAmount Minimum amount of the asset to receive
/// @param approxParams Approximation parameters for the binary search
/// @dev If approxParams.eps is zero, the binary search will use default binary search configuration.
struct NapierSwapYtEnterFuseData {
    ITokiPoolToken pool;
    uint256 amountIn;
    uint256 minimumAmount;
    ApproximationParams approxParams;
}

struct NapierSwapYtExitFuseData {
    ITokiPoolToken pool;
    uint256 amountIn;
    uint256 minimumAmount;
}

/// @title NapierSwapYtFuse
/// @notice Fuse for swapping PT for tokens via the universal router
/// @dev Substrates in this fuse are the Napier V2 Principal Tokens
contract NapierSwapYtFuse is NapierUniversalRouterFuse {
    using SafeERC20 for ERC20;

    /// @notice Canonical Permit2 address
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @param version Address of this contract version
    /// @param pool Address of the Napier V2 toki pool
    /// @param tokenIn Asset supplied into the router
    /// @param amountOut Amount of PTs/YTs issued to the vault
    event NapierSwapYtFuseEnter(address version, address pool, address tokenIn, uint256 amountOut);

    event NapierSwapYtFuseExit(address version, address pool, address tokenOut, uint256 amountOut);

    constructor(uint256 marketId_, address router_) {
        VERSION = address(this);
        if (marketId_ == 0) revert NapierFuseIInvalidMarketId();
        if (router_ == address(0)) revert NapierFuseIInvalidRouter();

        MARKET_ID = marketId_;
        ROUTER = IUniversalRouter(router_);
    }

    function enter(NapierSwapYtEnterFuseData calldata data_) external {
        if (data_.amountIn == 0) {
            return;
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, address(ROUTER))) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, PERMIT2)) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, address(data_.pool))) {
            revert NapierFuseIInvalidToken();
        }

        PoolKey memory key = _getPoolKey(data_.pool);
        address yt = IPrincipalToken(Currency.unwrap(key.currency1)).i_yt();

        address underlying = Currency.unwrap(key.currency0);
        address pt = Currency.unwrap(key.currency1);

        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, underlying)) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, pt)) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, yt)) {
            revert NapierFuseIInvalidToken();
        }
        if (data_.minimumAmount == 0) {
            revert NapierFuseIInvalidToken();
        }

        // Buy YT with the underlying token
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.YT_SWAP_UNDERLYING_FOR_YT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(
            key,
            data_.amountIn,
            data_.minimumAmount,
            address(this), // receiver=this
            address(this), // refundRecipient=this
            data_.approxParams
        );

        uint256 balanceBefore = ERC20(yt).balanceOf(address(this));

        _setupPermit2Approval(underlying, data_.amountIn);
        ROUTER.execute(commands, inputs, block.timestamp);
        _clearPermit2Approval(underlying);

        uint256 balanceAfter = ERC20(yt).balanceOf(address(this));
        if (balanceAfter < balanceBefore) {
            revert NapierFuseIInsufficientOutput();
        }
        uint256 amountOut = balanceAfter - balanceBefore;
        if (amountOut < data_.minimumAmount) {
            revert NapierFuseIInsufficientOutput();
        }

        emit NapierSwapYtFuseEnter(VERSION, address(data_.pool), yt, amountOut);
    }

    function exit(NapierSwapYtExitFuseData calldata data_) external {
        if (data_.amountIn == 0) {
            return;
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, address(ROUTER))) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, PERMIT2)) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, address(data_.pool))) {
            revert NapierFuseIInvalidToken();
        }

        PoolKey memory key = _getPoolKey(data_.pool);
        address underlying = Currency.unwrap(key.currency0);
        address pt = Currency.unwrap(key.currency1);
        address yt = IPrincipalToken(pt).i_yt();

        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, underlying)) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, pt)) {
            revert NapierFuseIInvalidToken();
        }
        if (!PlasmaVaultConfigLib.isSubstrateAsAssetGranted(MARKET_ID, yt)) {
            revert NapierFuseIInvalidToken();
        }
        if (data_.minimumAmount == 0) {
            revert NapierFuseIInvalidToken();
        }

        // Sell PT for the underlying token
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.YT_SWAP_YT_FOR_UNDERLYING)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(key, data_.amountIn, data_.minimumAmount, address(this)); // receiver=this

        uint256 balanceBefore = key.currency0.balanceOf(address(this));

        _setupPermit2Approval(yt, data_.amountIn);
        ROUTER.execute(commands, inputs, block.timestamp);
        _clearPermit2Approval(yt);

        uint256 balanceAfter = key.currency0.balanceOf(address(this));
        if (balanceAfter < balanceBefore) {
            revert NapierFuseIInsufficientOutput();
        }
        uint256 amountOut = balanceAfter - balanceBefore;
        if (amountOut < data_.minimumAmount) {
            revert NapierFuseIInsufficientOutput();
        }

        emit NapierSwapYtFuseExit(VERSION, address(data_.pool), Currency.unwrap(key.currency0), amountOut);
    }

    /// @notice Sets up Permit2 approval for the router to pull tokens
    /// @param token The token to approve
    /// @param amount The allowance to grant for this execution
    function _setupPermit2Approval(address token, uint256 amount) private {
        if (amount > type(uint160).max) {
            revert NapierFuseIInvalidToken();
        }

        ERC20(token).forceApprove(PERMIT2, amount);
        IPermit2(PERMIT2).approve(token, address(ROUTER), uint160(amount), uint48(block.timestamp + 1 hours));
    }

    /// @notice Clears Permit2 approval after router execution to minimize allowance risk
    /// @param token The token to reset approvals for
    function _clearPermit2Approval(address token) private {
        ERC20(token).forceApprove(PERMIT2, 0);
        IPermit2(PERMIT2).approve(token, address(ROUTER), 0, 0);
    }
}
