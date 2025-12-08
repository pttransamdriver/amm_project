# Wash Trading Vulnerability Analysis

## 🔍 Executive Summary

**Overall Risk Level: MODERATE-HIGH**

Your AMM project has **several wash trading vulnerabilities** that could be exploited by malicious actors to:
- Artificially inflate trading volume
- Manipulate token prices
- Extract value from liquidity providers
- Game flashloan fee structures

## ⚠️ Critical Vulnerabilities Found

### 1. **No Transaction Origin Tracking** ❌ HIGH RISK

**Location:** `AMM.sol` - All swap functions

**Issue:**
```solidity
function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256)
function swapSecondToken(uint256 _secondTokenAmount) external nonReentrant returns (uint256)
```

**Vulnerability:**
- No tracking of `tx.origin` vs `msg.sender`
- A single user can create multiple contracts to trade back and forth
- No cooldown period between trades
- No detection of circular trading patterns

**Exploit Scenario:**
```
User deploys Contract A and Contract B
Contract A: Swap 100 Token1 → Token2
Contract B: Swap 100 Token2 → Token1
Repeat 1000 times in same block
Result: Artificial volume, price manipulation, LP fee extraction
```

**Impact:**
- ✅ Reentrancy protected (good!)
- ❌ Same user can wash trade through multiple addresses
- ❌ No volume authenticity guarantees
- ❌ LPs pay gas but receive minimal real fees

---

### 2. **No Minimum Trade Size** ❌ MODERATE RISK

**Location:** `AMM.sol` lines 124-137, 164-177

**Issue:**
```solidity
function calculateFirstTokenSwap(uint256 _firstTokenAmount) public view returns (uint256) {
    require(_firstTokenAmount > 0 && constantProductK > 0, "Invalid swap or pool not initialized");
    // No minimum trade size check
}
```

**Vulnerability:**
- Allows dust trades (1 wei swaps)
- Enables high-frequency wash trading with minimal cost
- Can manipulate TWAP (Time-Weighted Average Price) if implemented later

**Exploit Scenario:**
```
for (i = 0; i < 10000; i++) {
    swap(1 wei Token1 → Token2)
    swap(1 wei Token2 → Token1)
}
Result: 20,000 fake transactions, inflated volume metrics
```

---

### 3. **Flashloan Self-Trading** ❌ HIGH RISK

**Location:** `AMM.sol` lines 231-289, `FlashLoanHub.sol`

**Issue:**
```solidity
function flashLoanFirstToken(uint256 _amount, bytes calldata _params) external nonReentrant {
    // No restriction on what the borrower does with the tokens
    // Borrower can trade on the same AMM they borrowed from
}
```

**Vulnerability:**
- User can flashloan from AMM, trade on same AMM, repay loan
- Creates artificial volume with zero capital
- Manipulates price within single transaction
- Extracts value from LPs through fee arbitrage

**Exploit Scenario:**
```
1. Flashloan 10,000 Token1 from AMM (fee: 0.09%)
2. Swap 10,000 Token1 → Token2 on same AMM (fee: 0.3%)
3. Swap Token2 → Token1 on another DEX
4. Repay flashloan + fee
5. Keep profit from price manipulation
```

**Impact:**
- Price manipulation within single transaction
- LP value extraction
- Fake volume inflation
- Oracle manipulation if AMM is used as price source

---

### 4. **No Trade Frequency Limits** ❌ MODERATE RISK

**Location:** All swap functions

**Issue:**
- No cooldown between trades from same address
- No rate limiting per block
- No maximum trades per address per time period

**Vulnerability:**
```solidity
// User can do this in a single transaction:
for (uint i = 0; i < 100; i++) {
    amm.swapFirstToken(amount);
    amm.swapSecondToken(amount);
}
```

---

### 5. **Arbitrage Strategy Wash Trading** ❌ MODERATE RISK

**Location:** `SimpleArbitrage.sol`, `TriangularArbitrage.sol`

**Issue:**
```solidity
function execute(address token, uint256 amount, uint256 fee, bytes calldata data) 
    external override returns (bool) {
    // No verification that dexA and dexB are different
    // No verification that trades are economically rational
}
```

**Vulnerability:**
- Strategy can specify same DEX as both dexA and dexB
- Can create circular trades: AMM → AMM → AMM
- No minimum profit enforcement at contract level (only in params)

**Exploit Scenario:**
```
SimpleArbitrage.execute({
    dexA: AMM_ADDRESS,
    dexB: AMM_ADDRESS,  // Same DEX!
    tokenIn: Token1,
    tokenOut: Token2,
    minProfit: 0
})
Result: Wash trade disguised as arbitrage
```

---

### 6. **No Slippage Protection for LPs** ❌ MODERATE RISK

**Location:** `AMM.sol` - Swap functions

**Issue:**
- Large wash trades can temporarily manipulate price
- LPs have no protection against sandwich attacks
- No maximum price impact per trade

---

## 🛡️ Recommended Fixes

### Priority 1: Critical Fixes (Implement Immediately)

#### Fix 1: Add Minimum Trade Size
```solidity
uint256 public constant MINIMUM_TRADE_AMOUNT = 1000; // 0.000000000000001 tokens

function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256) {
    require(_firstTokenAmount >= MINIMUM_TRADE_AMOUNT, "Trade too small");
    // ... rest of function
}
```

#### Fix 2: Prevent Flashloan Self-Trading
```solidity
mapping(address => bool) private activeFlashLoan;

function flashLoanFirstToken(uint256 _amount, bytes calldata _params) external nonReentrant {
    activeFlashLoan[msg.sender] = true;
    // ... flashloan logic
    activeFlashLoan[msg.sender] = false;
}

function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256) {
    require(!activeFlashLoan[msg.sender], "Cannot trade during flashloan");
    // ... rest of function
}
```

#### Fix 3: Add Trade Cooldown
```solidity
mapping(address => uint256) public lastTradeBlock;
uint256 public constant TRADE_COOLDOWN = 1; // 1 block cooldown

function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256) {
    require(block.number > lastTradeBlock[msg.sender] + TRADE_COOLDOWN, "Trade cooldown active");
    lastTradeBlock[msg.sender] = block.number;
    // ... rest of function
}
```

#### Fix 4: Validate Arbitrage Strategy DEXs
```solidity
// In SimpleArbitrage.sol
function execute(address token, uint256 amount, uint256 fee, bytes calldata data)
    external override returns (bool) {
    ArbitrageParams memory params = abi.decode(data, (ArbitrageParams));

    require(params.dexA != params.dexB, "DEXs must be different");
    require(params.minProfit > fee, "Min profit must exceed fee");
    // ... rest of function
}
```

#### Fix 5: Add Maximum Price Impact
```solidity
uint256 public constant MAX_PRICE_IMPACT = 500; // 5% max price impact (500/10000)

function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256) {
    uint256 priceImpact = (_firstTokenAmount * 10000) / firstTokenReserve;
    require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");
    // ... rest of function
}
```

---

### Priority 2: Enhanced Detection (Implement Soon)

#### Fix 6: Track Trading Patterns
```solidity
struct TradeHistory {
    uint256 totalVolume;
    uint256 tradeCount;
    uint256 lastResetBlock;
}

mapping(address => TradeHistory) public tradeHistory;
uint256 public constant HISTORY_RESET_BLOCKS = 100; // Reset every 100 blocks

function _recordTrade(address trader, uint256 amount) internal {
    TradeHistory storage history = tradeHistory[trader];

    if (block.number > history.lastResetBlock + HISTORY_RESET_BLOCKS) {
        history.totalVolume = 0;
        history.tradeCount = 0;
        history.lastResetBlock = block.number;
    }

    history.totalVolume += amount;
    history.tradeCount += 1;

    // Flag suspicious activity
    require(history.tradeCount < 50, "Too many trades in period");
}
```

#### Fix 7: Implement Trade Direction Tracking
```solidity
mapping(address => bool) public lastTradeDirection; // true = first→second, false = second→first

function swapFirstToken(uint256 _firstTokenAmount) external nonReentrant returns (uint256) {
    // Penalize immediate reverse trades
    if (lastTradeBlock[msg.sender] == block.number && !lastTradeDirection[msg.sender]) {
        revert("No reverse trades in same block");
    }
    lastTradeDirection[msg.sender] = true;
    // ... rest of function
}
```

---

### Priority 3: Economic Disincentives (Consider for V2)

#### Fix 8: Progressive Fee Structure
```solidity
function calculateTradeFee(address trader, uint256 amount) public view returns (uint256) {
    uint256 baseFee = 997; // 0.3%

    // Increase fee for high-frequency traders
    if (tradeHistory[trader].tradeCount > 10) {
        baseFee = 995; // 0.5%
    }
    if (tradeHistory[trader].tradeCount > 25) {
        baseFee = 990; // 1.0%
    }

    return (amount * baseFee) / 1000;
}
```

#### Fix 9: Minimum Hold Time for Flashloans
```solidity
mapping(address => uint256) public flashLoanTimestamp;

function flashLoanFirstToken(uint256 _amount, bytes calldata _params) external nonReentrant {
    flashLoanTimestamp[msg.sender] = block.timestamp;
    // ... flashloan logic

    // Require minimum time has passed before allowing trades
    require(block.timestamp > flashLoanTimestamp[msg.sender] + 1, "Flashloan cooldown");
}
```

---

## 📊 Vulnerability Impact Matrix

| Vulnerability | Severity | Exploitability | Impact on LPs | Impact on Price | Fix Difficulty |
|---------------|----------|----------------|---------------|-----------------|----------------|
| No Origin Tracking | HIGH | Easy | High | High | Medium |
| No Min Trade Size | MODERATE | Very Easy | Medium | Medium | Easy |
| Flashloan Self-Trading | HIGH | Easy | High | Very High | Medium |
| No Frequency Limits | MODERATE | Easy | Medium | Medium | Easy |
| Arbitrage Wash Trading | MODERATE | Medium | Medium | High | Easy |
| No Slippage Protection | MODERATE | Medium | High | Medium | Medium |

---

## 🎯 Recommended Implementation Plan

### Phase 1: Quick Wins (1-2 days)
1. ✅ Add minimum trade size (Fix 1)
2. ✅ Validate arbitrage DEXs are different (Fix 4)
3. ✅ Add maximum price impact (Fix 5)

### Phase 2: Core Protection (3-5 days)
4. ✅ Prevent flashloan self-trading (Fix 2)
5. ✅ Add trade cooldown (Fix 3)
6. ✅ Track trading patterns (Fix 6)

### Phase 3: Advanced Detection (1-2 weeks)
7. ✅ Implement trade direction tracking (Fix 7)
8. ✅ Progressive fee structure (Fix 8)
9. ✅ Flashloan cooldown (Fix 9)

---

## 🔬 Testing Recommendations

### Test Cases to Add:

1. **Wash Trading Attack Test**
```javascript
it("Should prevent wash trading through multiple contracts", async () => {
    // Deploy two contracts controlled by same user
    // Attempt circular trades
    // Verify cooldown prevents exploitation
});
```

2. **Flashloan Self-Trade Test**
```javascript
it("Should prevent trading during active flashloan", async () => {
    // Take flashloan
    // Attempt to swap on same AMM
    // Verify transaction reverts
});
```

3. **Dust Trade Test**
```javascript
it("Should reject trades below minimum size", async () => {
    await expect(amm.swapFirstToken(1)).to.be.revertedWith("Trade too small");
});
```

4. **High Frequency Test**
```javascript
it("Should enforce trade cooldown", async () => {
    await amm.swapFirstToken(amount);
    await expect(amm.swapFirstToken(amount)).to.be.revertedWith("Trade cooldown active");
});
```

---

## 📈 Monitoring Recommendations

### On-Chain Metrics to Track:

1. **Volume Concentration**
   - % of volume from top 10 addresses
   - Alert if >50% from single address

2. **Trade Patterns**
   - Ratio of reverse trades (A→B followed by B→A)
   - Alert if >30% are reverse trades

3. **Flashloan Usage**
   - Flashloan volume vs regular trade volume
   - Alert if flashloan trades show consistent profits

4. **Price Volatility**
   - Standard deviation of price changes
   - Alert on unusual spikes

---

## ⚖️ Trade-offs to Consider

### Implementing Anti-Wash-Trading Measures:

**Pros:**
- ✅ Protects liquidity providers
- ✅ Ensures authentic price discovery
- ✅ Builds trust with users
- ✅ Prevents oracle manipulation
- ✅ Reduces gas waste

**Cons:**
- ❌ May reduce total volume (but increases quality)
- ❌ Adds gas costs for checks
- ❌ May frustrate legitimate high-frequency traders
- ❌ Requires ongoing monitoring and tuning

---

## 🚨 Immediate Action Items

1. **DO NOT deploy to mainnet** without implementing at least Priority 1 fixes
2. **Add comprehensive tests** for wash trading scenarios
3. **Consider professional audit** focusing on economic attacks
4. **Implement monitoring** before mainnet launch
5. **Document trade limits** clearly in user documentation

---

## 📚 Additional Resources

- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf) - See their approach to MEV
- [Balancer V2 Security](https://docs.balancer.fi/concepts/security/) - Rate limiting examples
- [Curve Finance](https://curve.fi/) - Anti-manipulation techniques
- [Flashbots](https://docs.flashbots.net/) - MEV protection strategies

---

**Last Updated:** 2025-12-08
**Risk Assessment:** MODERATE-HIGH
**Recommended Action:** Implement Priority 1 fixes before mainnet deployment

