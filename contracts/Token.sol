// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

// Import the solidity hardhat tools
import "hardhat/console.sol";

// The "Token" Contract - This contract implements a basic ERC20 token with transfer, approval, and transferFrom functionality
contract Token {
    // A string(or word) variable that can be seen outside the contract by using the public "visibility" flag.
    string public tokenName;
    // A string(or word) variable that can be seen outside the contract by using the public "visibility" flag.
    string public tokenSymbol;
    // An unsigned integer variable that can be ((2^256)-1) characters long that can be seen outside the contract. This declares the decimal places of the token to have 18 decimal places making it the same as ETH. This is a common practice in the ERC20 standard
    uint256 public decimalPlaces = 18;
    // An unsigned integer variable that can be ((2^256)-1) characters long that can be seen outside the contract. This variable is meant to keep track of the token's (the token we are making with this contract) total supply.
    uint256 public tokenTotalSupply;

    // Mapping that associates each address with their token balance. This is a key-value store where the key is an Ethereum address and the value is their token balance.
    mapping(address => uint256) public balanceOf;
    // A nested mapping that keeps track of allowances. This is a mapping of owner addresses to a mapping of spender addresses to amounts.
    // It tracks how many tokens the spender is allowed to transfer on behalf of the owner.
    mapping(address => mapping(address => uint256)) public tokenAllowance;

    // Event emitted when tokens are transferred from one address to another.
    // The 'indexed' keyword makes it easier to filter and search for these events.
    event Transfer(
        address indexed senderAddress,
        address indexed receiverAddress,
        uint256 transferAmount
    );

    // Event emitted when an address approves another address to spend tokens on its behalf.
    // The 'indexed' keyword makes it easier to filter and search for these events.
    event Approval(
        address indexed ownerAddress,
        address indexed spenderAddress,
        uint256 approvedAmount
    );

    // Constructor function that runs once when the contract is deployed.
    // It initializes the token with a name, symbol, and total supply.
    constructor(
        string memory initialTokenName,
        string memory initialTokenSymbol,
        uint256 initialTotalSupply
    ) {
        // Set the token name to the provided name
        tokenName = initialTokenName;
        // Set the token symbol to the provided symbol
        tokenSymbol = initialTokenSymbol;
        // Calculate the total supply with the correct number of decimal places
        // We multiply by 10^decimalPlaces to account for the decimal representation
        tokenTotalSupply = initialTotalSupply * (10**decimalPlaces);
        // Assign the entire token supply to the contract deployer (msg.sender)
        balanceOf[msg.sender] = tokenTotalSupply;
    }

    // Public function that allows a user to transfer their tokens to another address
    // Returns a boolean indicating whether the transfer was successful
    function transfer(address receiverAddress, uint256 transferAmount)
        public
        returns (bool transferSuccess)
    {
        // Check if the sender has enough tokens to transfer
        require(balanceOf[msg.sender] >= transferAmount, "Insufficient balance for transfer");

        // Call the internal _transfer function to handle the actual transfer logic
        _transfer(msg.sender, receiverAddress, transferAmount);

        // Return true to indicate the transfer was successful
        return true;
    }

    // Internal function that handles the actual token transfer logic
    // This is called by both transfer and transferFrom functions
    function _transfer(
        address senderAddress,
        address receiverAddress,
        uint256 transferAmount
    ) internal {
        // Ensure the recipient is not the zero address (burning tokens unintentionally)
        require(receiverAddress != address(0), "Cannot transfer to the zero address");

        // Subtract the transfer amount from the sender's balance
        balanceOf[senderAddress] = balanceOf[senderAddress] - transferAmount;
        // Add the transfer amount to the receiver's balance
        balanceOf[receiverAddress] = balanceOf[receiverAddress] + transferAmount;

        // Emit a Transfer event to log this transaction on the blockchain
        emit Transfer(senderAddress, receiverAddress, transferAmount);
    }

    // Public function that allows a user to approve another address (spender) to spend tokens on their behalf
    // Returns a boolean indicating whether the approval was successful
    function approve(address spenderAddress, uint256 approvedAmount)
        public
        returns(bool approvalSuccess)
    {
        // Ensure the spender is not the zero address
        require(spenderAddress != address(0), "Cannot approve the zero address as spender");

        // Set the allowance for the spender to the approved amount
        tokenAllowance[msg.sender][spenderAddress] = approvedAmount;

        // Emit an Approval event to log this approval on the blockchain
        emit Approval(msg.sender, spenderAddress, approvedAmount);
        // Return true to indicate the approval was successful
        return true;
    }

    // Public function that allows a spender to transfer tokens from an owner's address to another address
    // This can only be called if the owner has approved the spender to spend at least the transfer amount
    function transferFrom(
        address ownerAddress,
        address receiverAddress,
        uint256 transferAmount
    )
        public
        returns (bool transferSuccess)
    {
        // Check if the owner has enough tokens to transfer
        require(transferAmount <= balanceOf[ownerAddress], "Owner has insufficient balance");
        // Check if the spender is allowed to transfer this amount
        require(transferAmount <= tokenAllowance[ownerAddress][msg.sender], "Spender has insufficient allowance");

        // Reduce the spender's allowance by the transfer amount
        tokenAllowance[ownerAddress][msg.sender] = tokenAllowance[ownerAddress][msg.sender] - transferAmount;

        // Call the internal _transfer function to handle the actual transfer logic
        _transfer(ownerAddress, receiverAddress, transferAmount);

        // Return true to indicate the transfer was successful
        return true;
    }
}