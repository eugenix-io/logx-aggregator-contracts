# LogX Aggregator 

LogX is a perpetual trading aggregator which allows users to seamlessly get the best trade on multiple perpetual trading exchanges across chains.

## Overview 

`Proxy Factory` is the contract with external functions for users/UI to interact with. For every position a user opens from a `Proxy Factory`, an `exchange adapter` (or `Exchange Adapter`) contract will be deployed which will, in turn, open a position on the exchange for the user. Any subsequent modifications to the position (placing an order, modifying the order, closing the position, etc) will be handled via the same `exchange adapter` contract.

## MUX Proxy Factory User Trade Functions

### Open and Close Positions
```solidity
function openPosition(PositionArgs calldata args, PositionOrderExtra calldata extra) external payable
function closePosition(PositionArgs calldata args, PositionOrderExtra calldata extra) external payable
```
Note - in case of MUX, PositionArgs are common for opening and closing positions - both these functions internally call ‘placePositionOrder()’ on exchange adapter.
We still have two separate functions for opening and closing positions instead of one to maintain consistency with the GMX interface.

#### PositionArgs
```solidity
struct PositionArgs {
   uint256 exchangeId;
   address collateralToken;
   address assetToken;
   address profitToken;
   bool isLong;
   uint96 collateralAmount; // tokenIn.decimals
   uint96 size; // 1e18
   uint96 price; // 1e18
   uint96 collateralPrice;
   uint96 assetPrice;
   uint8 flags; // MARKET, TRIGGER
   bytes32 referralCode;
   uint32 deadline;
}
```
1.  **exchangeId :** every exchange on logX aggregator has its own exchange ID. Used for creating an exchange adapter for the user's position. Currently, exchange ID for GMX is 0 and MUX is 1
2. **collateralToken :** address of the token being used as collateral for the position. Used for creating an exchange adapter for the user's position. In the case of MUX, this is the token which will be deposited as collateral by the user (which is not the case with GMX - we will look into that shortly in this documentation). If the address supplied is not supported by the exchange, it might cause a revert while opening the position, therefore, the user has to make sure the collateral address supplied here is supported by the exchange.
3. **assetToken :** address of the token being used as asset for the exchange. Used for creating an exchange adapter for the user's position. If the address supplied is not supported by the exchange, it might cause a revert while opening the position, therefore, the user has to make sure the collateral address supplied here is supported by the exchange.
4. **profitToken :** address of the token in which the user wants to redeem profits. This address is only used while closing a Position. While opening a position on MUX, the profitToken will automatically be set to ‘0’ to avoid reverting on side of MUX.
5. **isLong :** true if user wants to enter a long position else false.
6. **collateralAmount :** Amount of the ‘collateralToken’ the user wants to deposit for opening the position. Collateral Amount for MUX Adapter should be denominated in terms of the decimals of the collateral token. 
```Example - if the user wants to long 20 DAI, the collateral amount should be 20 X (10 ^ DAI Decimals)```
7. **size :** position size. Size has to be denominated in 1e18 and has to be a USD value.
```Example : if the user wants to long 2BTC, the size of the position will be 2 * price of BTC * (10 ^ 18)```
8. **price :** price of the limit or trigger order. Price has to be denominated in 1e18 and has to be a USD value.
```Example : if the user wants to set a limit price of 1900 ETH, the price of the position will be 1900 * (10 ^ 18)```
9. **collateralPrice :** price of the collateral Token in USD - this value is not passed to MUX, but rather used by the exchange adapter (or Exchange Adapter) to check if the Margin of the position is safe. Collateral Price has to be denominated in 1e18 and has to be a USD value.
```Example : if the price of the collateral token is $150, the collateralPrice for the position will be 150 * (10 ^ 18)```
10. **assetPrice :** price of the underlying Token in USD - this value is not passed to MUX, but rather used by the exchange adapter (or Exchange Adapter) to check if the Margin of the position is safe. Collateral Price has to be denominated in 1e18 and has to be a USD value.
```Example : if the price of the asset token is $500, the collateralPrice for the position will be 500 * (10 ^ 18)```
11. **flags :** flags will be used to determine the position the user wants to enter - the same value will be passed on to MUX OrderBook.
Following are the different types of Flags - 
```
POSITION_OPEN = 0x80; // this flag means openPosition; otherwise closePosition
POSITION_MARKET_ORDER = 0x40; // this flag means ignore limitPrice
POSITION_WITHDRAW_ALL_IF_EMPTY = 0x20; // this flag means auto withdraw all collateral if position.size == 0
POSITION_TRIGGER_ORDER = 0x10; // this flag means this is a trigger order (ex: stop-loss order). otherwise this is a limit order (ex: take-profit order)
POSITION_TPSL_STRATEGY = 0x08; // for open-position-order, this flag auto place take-profit and stop-loss orders when open-position-order fills.for close-position-order, this flag means ignore limitPrice and profitTokenId, and use extra.tpPrice, extra.slPrice, extra.tpslProfitTokenId instead.`
Example : If the user wants to open a market order, the flags will be 0x80 + 0x40.
```
**NOTE on limit and trigger orders :**
Limit Order is Take Profit order while Trigger order is a Stop Loss Order.
Following is the table on how the price of these orders are related to tradingPrice of the asset - 
```
open,long      0,0   0,1   1,1   1,0
limitOrder     <=    >=    <=    >=
triggerOrder   >=    <=    >=    <=
Example : if the user opens a long position for limit order, the tradingPrice <= limitOrderPrice. If the user opens a short position for trigger order, the tradingPrice <= triggerOrderPrice.
```

**NOTE on TPSL strategy :**
On MUX, if the user wants to close a position with TPSL strategy, the following additional conditions should be met - 
```
price == 0 (since tpsl extra parameter price will be used)
collateralAmount == 0 (tp/sl strategy only support POSITION_WITHDRAW_ALL_IF_EMPTY and we cannot add more collateral while placing a close Position TPSL order)
profitTokenId == 0 (profit token ID mentioned in the tpsl extra parameters will be used) flags cannot have MARKET_ORDER. (Since TPSL for close does not support market orders).
```
12. **referralCode :** following parameter is not being used since we inject logX referral code into exchange adapter. For now this value can be null.
13. **deadline :** deadline before the order expires. Deadline should be 0 for Market Orders - even if the user give a deadline for a market order by mistake, the proxy factory makes sure the deadline for market orders is set to 0.
14. **msg.value :** if the collateralToken is _weth, then the msg.value should be equal to collateralAmount. If collateralToken is not _weth, then msg.value should be equal to 0. 

### Order Management
```solidity
function getPendingOrderKeys(uint256 exchangeId, address collateralToken, address assetToken, bool isLong) external view returns(uint64[] memory)
function cancelOrders(uint256 exchangeId, address collateralToken, address assetToken, bool isLong, uint64[] calldata keys) external
```
**keys :** list of the order keys we want to cancel

## GMX Proxy Factory User Trade Functions

Unlike MUX, GMX open and close Position function have different input arguments.
### Open Position
```solidity
function openPosition(OpenPositionArgs calldata args) external payable 
```

#### OpenPositionArgs
```solidity
struct OpenPositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn; // tokenIn.decimals
        uint256 minOut; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint96 tpPriceUsd; // 1e18
        uint96 slPriceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }
```
1. **exchangeId :** every exchange on logX aggregator has its own exchange ID. Used for creating an exchange adapter for the user's position. Currently, exchange ID for GMX is 0 and MUX is 1
2. **collateralTOken :** address of the token being used as collateral for the position. Used for creating an exchange adapter for the user's position. For a GMX Long Position, the collateral Token has to be same as assetToken, and collateral token cannot be a stable coin. For a Short Position, the collateral Token HAS to be a stable coin. We can determine which stable coin to use for a Short Position based on current swap fees between swapInToken and collateralToken.
3. **assetToken :** address of the token being used as underlying / asset for the position. Used for creating an exchange adapter for the user's position. For GMX Long Position, the collateralToken and the indexToken have to be the same. For GMX Short Position, the index token should NOT be a stable coin and it has to be shortable.
4. **isLong :** true if user wants to enter a long position else false.
5. **tokenIn :** address of the token which user will be depositing to the exchange as collateral. The difference between tokenIn and collateralToken is that, tokenIn will be swapped with collateralToken in order to open a GMX Position to follow the rules mentioned in 2.
6. **amountIn :** the amount of 'tokenIn' the user will be depositing as a collateral. amountIn has to be denominated in terms of the decimal of tokenIn. ```Example: If the user wants to deposit 2 WBTC as tokenIn, then amountIn will be 2*(10 ^ WBTC decimals) ```
7. **minOut :** minimum number of collateralToken to be received after swapping tokenIn with collateralToken. minOut has to be denominated in terms of the decimals of collateralToken. ```Example: If the user's collateralToken is USDC and tokenIn is WETH, then minOut has to be denominated in terms of the number of decimals of USDC.```
8. **sizeUsd :** size (in USD) of the position the user wants to enter. sizeUsd has to be denominated in 1e18.
9. **priceUsd :** limit price at which the position can be opened. priceUsd has to be denominated in 1e18.
10. **tpPriceUsd :** take profit price. tpPriceUsd has to be denominated in 1e18. NOTE that TPSL strategy is a closing order placed on GMX - it will take effect at the time of closing the position, not opening.
11. **slPriceUsd :** stop loss price. slPriceUsd has to be denominated in 1e18.
NOTE - in GMX, all USD values - price, size, etc (even for closePosition()) are denominated in 1e30 (not 1e18) so we will be adding the extra 12 decimals in exchange adapter. This is being done to maintain consistency for orders being placed via logX.
12. **flags :** flags will be used to determine the position the user wants to enter - the same value will NOT be passed on to GMX OrderBook.
Following are the different types of Flags - 
```
POSITION_MARKET_ORDER = 0x40
POSITION_TPSL_ORDER = 0x08
Example : If the user wants to open a tpsl order, the flags will be 0x08.
```
12. **referralCode :** following parameter is not being used since we inject logX referral code into exchange adapter. For now this value can be null.
13. **msg.value :** In GMX, the msg.value should have the executionFees which GMX charges. Everytime the user places a market / limit order in open / close position. If the msg.value is less than minimum execution fee of GMX, the transaction fails to go through.
NOTE that while placing a TPSL order, the user will be paying the execution Fees thrice (once to open position, once to create TP close order, once to create SL close order). In all other cases, the user will pay execution Fees only once.
If the collateralToken is specified as WETH, the msg.value should have amountIn + executionFees amount of ETH failing which the transaction will not go through.

### Close Position
```solidity
function closePosition(ClosePositionArgs calldata args) external payable 
```

#### ClosePositionArgs
```solidity
struct ClosePositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint96 tpPriceUsd; // 1e18
        uint96 slPriceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }
```
**NOTE -** the following documentation only talks about the arguments which have not been talked about in OpenPositionArgs. If an argument is present in OpenPositionArgs and not discussed, the reader should assume the same applied here.

1. **collateralUsd :** collateral amount in USD that the user wants to withdraw / decrease from the position. collateralUsd has to be denominated in 1e18.
2. **sizeUsd :** size of the position in USD that the user wants to withdraw / decrease from the position. sizeUsd has to be denominated in 1e18.

### Order Management
```solidity
function cancelOrders(uint256 exchangeId, address collateralToken, address assetToken, bool isLong, bytes32[] calldata keys) external
function updateOrder(uint256 exchangeId, address collateralToken, address assetToken, bool isLong, OrderParams[] memory orderParams) external
function getPendingOrderKeys(uint256 exchangeId, address collateralToken, address assetToken, bool isLong) external view returns(bytes32[] memory)
```
**keys :** list of the order keys we want to cancel

#### OrderParams
```solidity
struct OrderParams {
        bytes32 orderKey;
        uint256 collateralDelta;
        uint256 sizeDelta;
        uint256 triggerPrice;
        bool triggerAboveThreshold;
    }
```
1. **orderKey :** key of the order we want to update.
2. **collateralDelta :** additional increase / decrease in collateral amount for position. collateralDelta has to be denominated in 1e18.
2. **sizeDelta :** additional increase / decrease in size for position. sizeDelta has to be denominated in 1e18.
2. **triggerPrice :** new trigger price for order. triggerPrice has to be denominated in 1e18.
2. **triggerAboveThreshold :** true if order has to be triggered if the price is above the threshold and vice versa.

## Post Trade Functions

Following part of the document deals with functions that can be used to track user's positions and orders after they have placed a transactions

### Fetching User Position

Each Position is represented by an Adapter Proxy contract - any subsequent changes to the same position will be reflected in the contract.

To get the addresses of all adapter proxies belonging to a user
```solidity
function getProxiesOf(address account) public view returns (address[] memory)
```

We can call the following function in each of the proxy addresses to get position information 
```solidity
function accountState() external view returns (AccountState memory)
```

#### AccountState
```solidity
struct AccountState {
    address account;
    address collateralToken;
    address indexToken; // 160
    bool isLong; // 8
    uint8 collateralDecimals;
    bytes32[20] reserved;
}
```
**account :** address of the user who owns the position
Remaining parameters are self explainatory.

For additional information regarding the position, we will have to directly call functions of exchange's contract.
In order to get position details directly from exchange's contracts, we will need subAccountId and gmxPositionKey for MUX and GMX respectively.

#### MUX Position Details

Following function can be called in the adapter proxy to get the subAccountId associated with the position - 
```solidity
function getSubAccountId() external view returns(bytes32)
```

Once we get the subAccountId we can call the following function from MUX Getter (Liquidity Pool) to fetch more details regarding the subAccount
```solidity
function getSubAccount(
        bytes32 subAccountId
    )
        external
        view
        returns (uint96 collateral, uint96 size, uint32 lastIncreasedTime, uint96 entryPrice, uint128 entryFunding)
```

#### GMX Position Details

Following function can be called in the adapter proxy to get the gmxPositionKey associated with the position - 
```solidity
function getPositionKey() external view returns(bytes32)
```

Once we get the gmxPositionKey we can call the following function from GMX Vault to fetch more details regarding the position
```solidity
function getPosition(address _account, address _collateralToken, address _indexToken, bool _isLong) public override view returns (uint256, uint256, uint256, uint256, uint256, uint256, bool, uint256)
// 0 size, 
// 1 collateral, 
// 2 averagePrice, 
// 3 entryFundingRate, 
// 4 reserveAmount, 
// 5 realisedPnl, 
// 6 realisedPnl >= 0, 
// 7 lastIncreasedTime 
```

### Fetching User Orders

We can get the pending order keys of a user by querying the following function with the adapter proxy - 
```solidity
For MUX - 
function getPendingOrderKeys() external view returns (uint64[] memory)

For GMX - 
function getPendingOrderKeys() external view returns (bytes32[] memory)

Note the difference in datatypes of the return values
```

Once we get the order keys, in case of **GMX** we can query another function on our adapter proxy to fetch more information - 
```solidity
function getOrder(bytes32 orderKey) external view returns(bool isFilled, LibGmx.OrderHistory memory history)
```

#### Order History, Order Category and Order Receiver 
```solidity
struct OrderHistory {
    OrderCategory category; // 4
    OrderReceiver receiver; // 4
    uint64 index; // 64
    uint96 zero; // 96
    uint88 timestamp; // 80
}

enum OrderCategory {
    NONE,
    OPEN,
    CLOSE
}

enum OrderReceiver {
    PR_INC,
    PR_DEC,
    OB_INC,
    OB_DEC
}
```
1. **index :** GMX Order Index
2. **zero :** Empty space left for potential future use
3. **timestamp :** timestamp at which the order was placed
4. **PR_INC :** Increase Position Order plaed with Position Router (Market Order)
5. **PR_DEC :** Decrease Position Order plaed with Position Router (Market Order)
6. **OB_INC :** Increase Position Order plaed with Order Book (Limit Order)
7. **OB_DEC :** Decrease Position Order plaed with Order Book (Limit Order)

In case of **MUX** we have to call the following function directly from MUX Order Book-
```solidity
function getOrder(uint64 orderId) external view returns (bytes32[3] memory, bool)
```
Following is how the bytes32[3] return value looks like (The response has to be decoded) - 
```
//                                  160        152       144         120        96   72   64               8        0
// +----------------------------------------------------------------------------------+--------------------+--------+
// |              subAccountId 184 (already shifted by 72bits)                        |     orderId 64     | type 8 |
// +----------------------------------+----------+---------+-----------+---------+---------+---------------+--------+
// |              size 96             | profit 8 | flags 8 | unused 24 | exp 24  | time 32 |      enumIndex 64      |
// +----------------------------------+----------+---------+-----------+---------+---------+---------------+--------+
// |             price 96             |                    collateral 96                   |        unused 64       |
// +----------------------------------+----------------------------------------------------+------------------------+
```