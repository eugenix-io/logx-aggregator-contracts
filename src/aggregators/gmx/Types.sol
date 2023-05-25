// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

enum ExchangeConfigIds {
    VAULT,
    POSITION_ROUTER,
    ORDER_BOOK,
    ROUTER,
    REFERRAL_CODE,
    MARKET_ORDER_TIMEOUT_SECONDS,
    LIMIT_ORDER_TIMEOUT_SECONDS,
    END
}

enum TokenConfigIds {
    INITIAL_MARGIN_RATE,
    MAINTENANCE_MARGIN_RATE,
    LIQUIDATION_FEE_RATE,
    REFERRENCE_ORACLE,
    REFERRENCE_ORACLE_DEVIATION,
    END
}

struct ExchangeConfigs {
    address vault;
    address positionRouter;
    address orderBook;
    address router;
    bytes32 referralCode;
    // ========================
    uint32 marketOrderTimeoutSeconds;
    uint32 limitOrderTimeoutSeconds;
    bytes32[20] reserved;
}

struct TokenConfigs {
    address referrenceOracle;
    // --------------------------
    uint32 referenceDeviation;
    uint32 initialMarginRate;
    uint32 maintenanceMarginRate;
    uint32 liquidationFeeRate;
    // --------------------------
    bytes32[20] reserved;
}

struct AccountState {
    address account;
    address collateralToken;
    address indexToken; // 160
    bool isLong; // 8
    uint8 collateralDecimals;
    bytes32[20] reserved;
}

struct OpenPositionContext {
    // parameters
    uint256 amountIn;
    uint256 sizeUsd;
    uint256 priceUsd;
    bool isMarket;
    // calculated
    uint256 fee;
    uint256 amountOut;
    uint256 gmxOrderIndex;
    uint256 executionFee;
}

struct ClosePositionContext {
    uint256 collateralUsd;
    uint256 sizeUsd;
    uint256 priceUsd;
    bool isMarket;
    uint256 gmxOrderIndex;
}