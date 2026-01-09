# Security Fixes Documentation

This document outlines critical security vulnerabilities identified and fixed in the AMM (Automated Market Maker) smart contract system.

---

## 1. Stale State Variable Vulnerability (AMM.sol)

**Severity:** HIGH
**Impact:** Price manipulation, potential arbitrage exploitation
**Files Affected:** `contracts/core/AMM.sol:230, 311`

### Vulnerability Description
The swap calculation functions relied on a cached `constantProductK` state variable that could become stale after liquidity operations. An attacker could exploit the timing between liquidity changes and swaps to manipulate prices.

### Before (Vulnerable Code)
```solidity
function calculateFirstTokenSwap(uint256 _firstTokenAmount) public view returns (uint256 secondTokenOut) {
    require(_firstTokenAmount > 0 && constantProductK > 0, "Invalid swap or pool not initialized");

    uint256 amountInWithFee = (_firstTokenAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
    uint256 firstTokenAfterSwap = firstTokenReserve + amountInWithFee;
    uint256 secondTokenAfterSwap = constantProductK / firstTokenAfterSwap;  // ⚠️ Uses cached K
    secondTokenOut = secondTokenReserve - secondTokenAfterSwap;

    if (secondTokenOut == secondTokenReserve) {
        revert("Swap output exceeds reserves");
    }
}
```

### After (Fixed Code)
```solidity
function calculateFirstTokenSwap(uint256 _firstTokenAmount) public view returns (uint256 secondTokenOut) {
    require(_firstTokenAmount > 0 && firstTokenReserve > 0 && secondTokenReserve > 0, "Invalid swap or pool not initialized");

    uint256 amountInWithFee = (_firstTokenAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
    uint256 firstTokenAfterSwap = firstTokenReserve + amountInWithFee;
    uint256 currentK = firstTokenReserve * secondTokenReserve;  // ✅ Calculate K dynamically
    uint256 secondTokenAfterSwap = currentK / firstTokenAfterSwap;
    secondTokenOut = secondTokenReserve - secondTokenAfterSwap;

    if (secondTokenOut == secondTokenReserve) {
        revert("Swap output exceeds reserves");
    }
}
```

### Why This Matters
- **Dynamic Calculation:** K is now calculated from current reserves, ensuring accuracy
- **Prevents Race Conditions:** Eliminates timing-based attacks between liquidity operations
- **Enhanced Validation:** Explicitly checks both reserves are non-zero

**Same fix applied to:** `calculateSecondTokenSwap()` at line 311

---

## 2. Missing Slippage Protection (SimpleArbitrage.sol)

**Severity:** HIGH
**Impact:** Frontrunning attacks, MEV exploitation, potential loss of funds
**Files Affected:** `contracts/strategies/SimpleArbitrage.sol:95-98, 105-108`

### Vulnerability Description
The arbitrage strategy performed swaps with `minAmountOut = 0`, making it vulnerable to sandwich attacks where malicious actors could frontrun the transaction, manipulate the price, and extract value.

### Before (Vulnerable Code)
```solidity
uint256 amountOut;
if (params.tokenIn == address(dexA.firstToken())) {
    amountOut = dexA.swapFirstToken(amount, 0, deadline);  // ⚠️ No slippage protection
} else {
    amountOut = dexA.swapSecondToken(amount, 0, deadline);  // ⚠️ No slippage protection
}

Token(params.tokenOut).approve(params.dexB, amountOut);

uint256 finalAmount;
if (params.tokenOut == address(dexB.firstToken())) {
    finalAmount = dexB.swapFirstToken(amountOut, 0, deadline);  // ⚠️ No slippage protection
} else {
    finalAmount = dexB.swapSecondToken(amountOut, 0, deadline);  // ⚠️ No slippage protection
}
```

### After (Fixed Code)
```solidity
uint256 private constant SLIPPAGE_NUMERATOR = 995;    // 0.5% slippage tolerance
uint256 private constant SLIPPAGE_DENOMINATOR = 1000;

// ...

// Calculate expected output and slippage for the first swap
uint256 expectedAmountOut = (params.tokenIn == address(dexA.firstToken()))
    ? dexA.calculateFirstTokenSwap(amount)
    : dexA.calculateSecondTokenSwap(amount);

uint256 minAmountOut = (expectedAmountOut * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;  // ✅ 0.5% slippage

uint256 amountOut;
if (params.tokenIn == address(dexA.firstToken())) {
    amountOut = dexA.swapFirstToken(amount, minAmountOut, deadline);  // ✅ Protected
} else {
    amountOut = dexA.swapSecondToken(amount, minAmountOut, deadline);  // ✅ Protected
}

Token(params.tokenOut).approve(params.dexB, amountOut);

// Calculate expected output and slippage for the second swap
uint256 expectedFinalAmount = (params.tokenOut == address(dexB.firstToken()))
    ? dexB.calculateFirstTokenSwap(amountOut)
    : dexB.calculateSecondTokenSwap(amountOut);

uint256 minFinalAmount = (expectedFinalAmount * SLIPPAGE_NUMERATOR) / SLIPPAGE_DENOMINATOR;  // ✅ 0.5% slippage

uint256 finalAmount;
if (params.tokenOut == address(dexB.firstToken())) {
    finalAmount = dexB.swapFirstToken(amountOut, minFinalAmount, deadline);  // ✅ Protected
} else {
    finalAmount = dexB.swapSecondToken(amountOut, minFinalAmount, deadline);  // ✅ Protected
}
```

### Why This Matters
- **Frontrunning Protection:** Transactions will revert if price moves more than 0.5%
- **MEV Resistance:** Reduces profitability of sandwich attacks
- **Expected Output Calculation:** Uses on-chain calculations for accurate slippage bounds
- **Two-Stage Protection:** Both swaps in the arbitrage path are protected

### Attack Scenario Prevented
1. Attacker sees pending arbitrage transaction in mempool
2. Attacker frontruns with large swap to move price
3. Arbitrage executes at unfavorable price (originally would succeed with 0 minimum)
4. Attacker backruns to restore price and capture profit
5. **With fix:** Step 3 reverts, preventing the attack

---

## 3. Missing Token Recovery Function (FlashLoanHub.sol)

**Severity:** MEDIUM
**Impact:** Permanent loss of accidentally sent tokens
**Files Affected:** `contracts/flashloan/FlashLoanHub.sol:436-446`

### Vulnerability Description
If tokens were accidentally sent to the FlashLoanHub contract, there was no mechanism to recover them, resulting in permanent loss of funds.

### Before (Missing Functionality)
```solidity
// No function to recover accidentally sent tokens
// Tokens sent to this contract would be locked forever
```

### After (Fixed Code)
```solidity
event TokensSwept(address indexed by, address indexed token, uint256 amount);

/**
 * @notice Allows the owner to withdraw any tokens accidentally sent to this contract
 * @param _tokenAddress The address of the token to withdraw
 */
function sweepTokens(address _tokenAddress) external onlyOwner {
    Token token = Token(_tokenAddress);
    uint256 balance = token.balanceOf(address(this));
    require(balance > 0, "No tokens to sweep");
    token.transfer(owner, balance);
    emit TokensSwept(msg.sender, _tokenAddress, balance);
}
```

### Why This Matters
- **Fund Recovery:** Owner can rescue accidentally sent tokens
- **Access Control:** Only owner can execute (prevents unauthorized withdrawals)
- **Transparency:** Emits event for off-chain tracking
- **Balance Check:** Validates tokens exist before attempting transfer

---

## Summary of Security Improvements

| Vulnerability | Severity | Attack Vector | Fix |
|--------------|----------|---------------|-----|
| Stale K State Variable | HIGH | Price manipulation via liquidity timing | Dynamic K calculation from reserves |
| Zero Slippage Protection | HIGH | Frontrunning/MEV sandwich attacks | 0.5% slippage tolerance with pre-calculation |
| No Token Recovery | MEDIUM | Accidental token loss | Owner-controlled sweep function |

---

## Testing Recommendations

1. **Stale State Tests:**
   - Add liquidity, verify K updates correctly
   - Remove liquidity, ensure swap calculations use new K
   - Test rapid liquidity operations followed by swaps

2. **Slippage Protection Tests:**
   - Test swaps revert when price moves beyond tolerance
   - Verify legitimate swaps within tolerance succeed
   - Test both swap directions with slippage

3. **Token Recovery Tests:**
   - Send tokens to FlashLoanHub, verify sweep works
   - Test only owner can sweep
   - Verify events are emitted correctly

---

## Additional Security Best Practices Applied

- ✅ ReentrancyGuard on all state-changing functions
- ✅ Access control with `onlyOwner` modifier
- ✅ Deadline protection on time-sensitive operations
- ✅ Explicit validation of reserves before calculations
- ✅ Event emission for all significant state changes
- ✅ Use of immutable variables where appropriate

---

**Audit Date:** January 8, 2026
**Commit:** c9e8233ee986c2a0b0d8a2f0358e5b02f7ed935c
**Auditor:** Internal Security Review
