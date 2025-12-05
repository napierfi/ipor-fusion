// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {NapierPriceFeed, ITokiChainlinkCompatOracle} from "../../../contracts/price_oracle/price_feed/NapierPriceFeed.sol";
import {IPriceOracleMiddleware} from "../../../contracts/price_oracle/IPriceOracleMiddleware.sol";

/// @notice Simple middleware mock returning a fixed asset price.
contract NapierPriceMiddlewareMock is IPriceOracleMiddleware {
    uint256 private immutable _price;
    uint256 private immutable _decimals;

    constructor(uint256 price_, uint256 decimals_) {
        _price = price_;
        _decimals = decimals_;
    }

    function getAssetPrice(address) external view override returns (uint256 assetPrice, uint256 decimals) {
        return (_price, _decimals);
    }

    function getAssetsPrices(
        address[] calldata /*assets*/
    ) external pure override returns (uint256[] memory assetPrices, uint256[] memory decimalsList) {
        revert("unused");
    }

    function getSourceOfAssetPrice(address) external pure override returns (address) {
        revert("unused");
    }

    function setAssetsPricesSources(address[] calldata, address[] calldata) external pure override {
        revert("unused");
    }

    function QUOTE_CURRENCY() external pure override returns (address) {
        return address(0);
    }

    function QUOTE_CURRENCY_DECIMALS() external view override returns (uint256) {
        return _decimals;
    }
}

/// @notice Chainlink compatible oracle mock with static values.
contract NapierTokiOracleMock is ITokiChainlinkCompatOracle {
    uint8 private immutable _decimals;
    address private immutable _liquidityToken;
    address private immutable _base;
    address private immutable _quote;
    int256 private _unitPrice;
    uint256 private _timestamp;

    constructor(int256 unitPrice_, address liquidityToken_, address base_, address quote_, uint8 decimals_) {
        _unitPrice = unitPrice_;
        _liquidityToken = liquidityToken_;
        _base = base_;
        _quote = quote_;
        _decimals = decimals_;
        _timestamp = block.timestamp;
    }

    function parseImmutableArgs() external view override returns (address, address, address, uint256) {
        return (_liquidityToken, _base, _quote, 0);
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "napier-toki-oracle-mock";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 0;
        answer = _unitPrice;
        startedAt = _timestamp;
        updatedAt = _timestamp;
        answeredInRound = 0;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = _roundId;
        answer = _unitPrice;
        startedAt = _timestamp;
        updatedAt = _timestamp;
        answeredInRound = _roundId;
    }

    function setUnitPrice(int256 newPrice, uint256 newTimestamp) external {
        _unitPrice = newPrice;
        _timestamp = newTimestamp;
    }
}

/// @notice Unit tests for NapierPriceFeed middleware integration and decimals handling.
contract NapierPriceFeedTest is Test {
    NapierPriceMiddlewareMock private middleware;
    NapierTokiOracleMock private oracle;
    NapierPriceFeed private feed;

    function setUp() external {
        middleware = new NapierPriceMiddlewareMock(2e8, 8);
        oracle = new NapierTokiOracleMock(1e18, address(0xA1), address(0xA2), address(0xA3), 18);
        feed = new NapierPriceFeed(address(middleware), address(oracle));
    }

    function testLatestPriceUsesCallingMiddleware() external {
        vm.prank(address(middleware));
        (, int256 price, , , ) = feed.latestRoundData();

        assertEq(feed.decimals(), 18, "decimals should be 18");
        assertEq(price, 2e18, "middleware price should be scaled to 18 decimals");
    }

    function testLatestPriceFallsBackToConfiguredMiddlewareForEoaCaller() external {
        vm.prank(address(0xBEEF));
        (, int256 price, , , ) = feed.latestRoundData();

        assertEq(price, 2e18, "fallback middleware should serve pricing");
    }
}
