// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

// Import the hardhat console for debug logging
import "hardhat/console.sol";

// Main contract declaration
contract Token {
    string public name; // "name" here means the name of the token. 
    string public symbol; // "symbol" here means the symbol of the token. 
    uint256 public decimals = 18; // "decimals" here means the number of decimal places the token has. 
    uint256 public totalSupply; // "totalSupply" here means the total amount of tokens in circulation. Think, total tokens supplied

    // Mapping that keeps track of the balance of each address.
    mapping(address => uint256) public balanceOf;
    // Mapping that keeps track of the allowance of each address to spend tokens on behalf of another address.
    mapping(address => mapping(address => uint256)) public allowance;

    // Event that is emitted when tokens are transferred from one address to another.
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    // Event that is emitted when an allowance is set for an address to spend tokens on behalf of another address.
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // Constructor that is called when the contract is deployed.
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) {
        name =_name; // "name" the state variable is being converted to a parameter "_name" for standard solidity convention
        symbol = _symbol; // "symbol" the state variable is being converted to a parameter "_symbol" for standard solidity convention
        totalSupply = _totalSupply * (10**decimals); // "totalSupply" the state variable is being converted to a parameter "_totalSupply". The total supply the parameter is now multiplied by 10 to the power of the number of decimals. This is to account for the decimal places since solidity does not have decimal places.
        balanceOf[msg.sender] = totalSupply; // "balanceOf" the mapping is being used to set the balance of the address that deployed the contract to the total supply. The address that deployed the contract is "msg.sender".
        
    }

    // Function that handles the the external interface - validating the sender has enough balance and then calls the internal transfer function.
    function transfer(address _to, uint256 _value)
        public
        returns (bool success)
    {
        require(balanceOf[msg.sender] >= _value); // "require" is a keyword that checks if the condition is true. If it is not, the transaction is reverted. In this case, we are checking if the balance of the address that is calling the function is greater than or equal to the "_value" that is being transferred. If it is not, the transaction is reverted.
        _transfer(msg.sender, _to, _value); // "_transfer" is a function that is defined below. This function is used to transfer the tokens from one address to another. It is called internally because it is not part of the external interface. 
        return true; // "return" is a keyword that returns a value from a function. In this case, we are returning "true" to the "event" tracker to indicate that the transaction was successful.

    }

    // Internal function that transfers tokens from one address to another.
    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        require(_to != address(0)); // Require the destination address is not the zero address. This is just a solidity standard unless you want to let users burn their tokens.
        balanceOf[_from] -= _value; // Subtract the value from the balance of the sender.
        balanceOf[_to] += _value; // Add the value to the balance of the recipient.
        emit Transfer(_from, _to, _value); // Emit the transfer event for reference.
    }

    // Function that reaches out to the external interface to approve a spender to spend tokens on behalf of the owner.
    function approve(address _spender, uint256 _value)
        public
        returns (bool success)
    {
        require(_spender != address(0)); // Require the spender(metamask like wallet) is not the zero address. This is just a solidity standard.
        allowance[msg.sender][_spender] = _value; // Sets the amount "_value" to be the allowance of the spender. Stores this value in the "allowance" mapping. It's a mapping because it allows approves the token to go to a thing like ([Alice][100]) 100 tokens allowed to go to Alice.
        emit Approval(msg.sender, _spender, _value); // Emit the approval event for reference.
        return true;
    }

    // 
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        returns (bool success)
    {
        require(_value <= balanceOf[_from]); // Require the value of the tokens to be less than or equal to the balance of what's available to be purchased. 
        require(_value <= allowance[_from][msg.sender]); // Require the value of the tokens to be less than of equal to the allowed amount that the spender (like  metamask) is allowed to spend.
        allowance[_from][msg.sender] -= _value; // Subtract the "_value" from the allowance from the spender. 
        _transfer(_from, _to, _value); //This calls the internal "_transfer" function. It works by passing in the "_from" address, the "_to" address, and the "_value"arguments into the "_transfer" function.
        return true;
    } 
    
}
