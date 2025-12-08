#!/bin/bash

# AMM Project Reorganization Script
# This script reorganizes the project into a clean, category-based architecture

echo "🏗️  Starting AMM Project Reorganization..."
echo ""

# Create directory structure
echo "📁 Creating new directory structure..."
mkdir -p docs/deployment
mkdir -p docs/security
mkdir -p docs/technical
mkdir -p docs/archive
mkdir -p contracts/core
mkdir -p contracts/flashloan
mkdir -p scripts/deployment
mkdir -p scripts/management
mkdir -p scripts/testing
mkdir -p config

# Move Documentation Files
echo "📚 Organizing documentation..."

# Main README stays in root
# Move deployment docs
mv DEPLOYMENT_QUICK_REFERENCE.md docs/deployment/QUICK_START.md 2>/dev/null
mv DEPLOYMENT_SUMMARY.md docs/deployment/SUMMARY.md 2>/dev/null
mv SEPOLIA_VERCEL_DEPLOYMENT.md docs/deployment/SEPOLIA_DEPLOYMENT.md 2>/dev/null
mv VERCEL_SETUP.md docs/deployment/VERCEL_SETUP.md 2>/dev/null

# Move security docs
mv COMPREHENSIVE_SECURITY_AUDIT.md docs/security/SECURITY_AUDIT.md 2>/dev/null
mv WASH_TRADING_ANALYSIS.md docs/security/WASH_TRADING_ANALYSIS.md 2>/dev/null
mv SECURITY_FIXES.md docs/security/SECURITY_FIXES.md 2>/dev/null

# Move technical docs
mv DEEPDIVE.md docs/technical/ARCHITECTURE.md 2>/dev/null
mv FLASHLOAN_GUIDE.md docs/technical/FLASHLOAN_GUIDE.md 2>/dev/null

# Archive old/redundant docs
mv CRITICAL_FIXES_IMPLEMENTATION_COMPLETE.md docs/archive/ 2>/dev/null
mv FLASHLOAN_IMPLEMENTATION_SUMMARY.md docs/archive/ 2>/dev/null
mv MIGRATION_COMPLETE.md docs/archive/ 2>/dev/null
mv OPTIMIZATION_SUMMARY.md docs/archive/ 2>/dev/null
mv UPGRADE_NOTES.md docs/archive/ 2>/dev/null
mv WASH_TRADING_IMPLEMENTATION_COMPLETE.md docs/archive/ 2>/dev/null
mv NEXT_STEPS.md docs/archive/ 2>/dev/null

# Remove cruft
echo "🗑️  Removing cruft..."
rm -f WASH_TRADING_FIXES.sol 2>/dev/null

# Move Smart Contracts
echo "📜 Organizing smart contracts..."

# Core contracts
mv contracts/AMM.sol contracts/core/ 2>/dev/null
mv contracts/Token.sol contracts/core/ 2>/dev/null
mv contracts/PriceOracle.sol contracts/core/ 2>/dev/null

# FlashLoan contracts
mv contracts/FlashLoanHub.sol contracts/flashloan/ 2>/dev/null
mv contracts/FlashArbitrage.sol contracts/flashloan/ 2>/dev/null
mv contracts/IFlashLoanReceiver.sol contracts/flashloan/ 2>/dev/null

# Move Scripts
echo "⚙️  Organizing scripts..."

# Deployment scripts
mv scripts/deploy.js scripts/deployment/ 2>/dev/null
mv scripts/deploy-sepolia.js scripts/deployment/ 2>/dev/null
mv scripts/deploy-test.js scripts/deployment/ 2>/dev/null

# Management scripts
mv scripts/approve-strategies.js scripts/management/ 2>/dev/null
mv scripts/seed.js scripts/management/ 2>/dev/null

# Testing scripts
mv scripts/test-arbitrage.js scripts/testing/ 2>/dev/null

# Move Configuration Files
echo "🔧 Organizing configuration..."
mv hardhat.config.js config/ 2>/dev/null
mv vercel.json config/ 2>/dev/null
cp .env.example config/.env.example 2>/dev/null

# Create symlinks for backward compatibility
echo "🔗 Creating symlinks for backward compatibility..."
ln -sf config/hardhat.config.js hardhat.config.js 2>/dev/null
ln -sf config/vercel.json vercel.json 2>/dev/null

echo ""
echo "✅ Reorganization complete!"
echo ""
echo "📊 New Structure:"
echo "  docs/"
echo "    ├── deployment/     (4 files)"
echo "    ├── security/       (3 files)"
echo "    ├── technical/      (2 files)"
echo "    └── archive/        (7 files)"
echo "  contracts/"
echo "    ├── core/           (AMM, Token, PriceOracle)"
echo "    ├── flashloan/      (FlashLoanHub, FlashArbitrage, Interface)"
echo "    ├── interfaces/     (External DEX interfaces)"
echo "    ├── mocks/          (Test mocks)"
echo "    └── strategies/     (Arbitrage strategies)"
echo "  scripts/"
echo "    ├── deployment/     (3 deployment scripts)"
echo "    ├── management/     (2 management scripts)"
echo "    └── testing/        (1 test script)"
echo "  config/"
echo "    ├── hardhat.config.js"
echo "    ├── vercel.json"
echo "    └── .env.example"
echo ""
echo "⚠️  IMPORTANT: You need to update import paths!"
echo "   Run: node update-imports.js"
echo ""

