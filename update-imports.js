#!/usr/bin/env node

/**
 * Update Import Paths Script
 * Updates all import paths after reorganization
 */

const fs = require('fs');
const path = require('path');

console.log('🔄 Updating import paths...\n');

// Import path mappings
const contractMappings = {
  './AMM.sol': './core/AMM.sol',
  './Token.sol': './core/Token.sol',
  './PriceOracle.sol': './core/PriceOracle.sol',
  './FlashLoanHub.sol': './flashloan/FlashLoanHub.sol',
  './FlashArbitrage.sol': './flashloan/FlashArbitrage.sol',
  './IFlashLoanReceiver.sol': './flashloan/IFlashLoanReceiver.sol',
  '../AMM.sol': '../core/AMM.sol',
  '../Token.sol': '../core/Token.sol',
  '../PriceOracle.sol': '../core/PriceOracle.sol',
  '../FlashLoanHub.sol': '../flashloan/FlashLoanHub.sol',
  '../FlashArbitrage.sol': '../flashloan/FlashArbitrage.sol',
  '../IFlashLoanReceiver.sol': '../flashloan/IFlashLoanReceiver.sol',
};

const scriptMappings = {
  './deploy.js': './deployment/deploy.js',
  './deploy-sepolia.js': './deployment/deploy-sepolia.js',
  './seed.js': './management/seed.js',
};

// Update contract imports
function updateContractImports(filePath) {
  if (!fs.existsSync(filePath)) return;
  
  let content = fs.readFileSync(filePath, 'utf8');
  let updated = false;

  for (const [oldPath, newPath] of Object.entries(contractMappings)) {
    const regex = new RegExp(`import\\s+(.+)\\s+from\\s+["']${oldPath.replace(/\./g, '\\.')}["']`, 'g');
    if (regex.test(content)) {
      content = content.replace(regex, `import $1 from "${newPath}"`);
      updated = true;
    }
  }

  if (updated) {
    fs.writeFileSync(filePath, content);
    console.log(`✅ Updated: ${filePath}`);
  }
}

// Update script requires
function updateScriptRequires(filePath) {
  if (!fs.existsSync(filePath)) return;
  
  let content = fs.readFileSync(filePath, 'utf8');
  let updated = false;

  // Update hardhat.config.js path
  if (content.includes('require("hardhat")')) {
    content = content.replace(
      /require\("\.\.\/hardhat\.config\.js"\)/g,
      'require("../../config/hardhat.config.js")'
    );
    updated = true;
  }

  // Update config.json path
  if (content.includes('../src/config.json')) {
    content = content.replace(
      /require\("\.\.\/src\/config\.json"\)/g,
      'require("../../src/config.json")'
    );
    updated = true;
  }

  if (updated) {
    fs.writeFileSync(filePath, content);
    console.log(`✅ Updated: ${filePath}`);
  }
}

// Update hardhat config
function updateHardhatConfig() {
  const configPath = 'config/hardhat.config.js';
  if (!fs.existsSync(configPath)) return;

  let content = fs.readFileSync(configPath, 'utf8');
  
  // Update contract paths
  content = content.replace(
    /sources:\s*"\.\/contracts"/g,
    'sources: "../contracts"'
  );
  
  content = content.replace(
    /tests:\s*"\.\/test"/g,
    'tests: "../test"'
  );
  
  content = content.replace(
    /cache:\s*"\.\/cache"/g,
    'cache: "../cache"'
  );
  
  content = content.replace(
    /artifacts:\s*"\.\/artifacts"/g,
    'artifacts: "../artifacts"'
  );

  fs.writeFileSync(configPath, content);
  console.log(`✅ Updated: ${configPath}`);
}

// Process all contract files
console.log('📜 Updating contract imports...');
const contractDirs = [
  'contracts/core',
  'contracts/flashloan',
  'contracts/strategies',
  'contracts/mocks',
];

contractDirs.forEach(dir => {
  if (!fs.existsSync(dir)) return;
  
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.sol'));
  files.forEach(file => {
    updateContractImports(path.join(dir, file));
  });
});

// Process all script files
console.log('\n⚙️  Updating script imports...');
const scriptDirs = [
  'scripts/deployment',
  'scripts/management',
  'scripts/testing',
];

scriptDirs.forEach(dir => {
  if (!fs.existsSync(dir)) return;
  
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.js'));
  files.forEach(file => {
    updateScriptRequires(path.join(dir, file));
  });
});

// Update hardhat config
console.log('\n🔧 Updating hardhat config...');
updateHardhatConfig();

console.log('\n✅ All import paths updated!\n');
console.log('📝 Next steps:');
console.log('  1. Run: npx hardhat compile');
console.log('  2. Run: npx hardhat test');
console.log('  3. Verify everything works\n');

