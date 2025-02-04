// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

contract LockableContract {
    address private _owner;
    bool public contractEnabled = true;

    // Events to track status changes and ownership
    event ContractStatusChanged(bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Modifier to ensure that part of logic are allowed only by the owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "L2");
        _;
    }

    // Modifier to ensure the contract is enabled
    modifier whenContractEnabled() {
        require(contractEnabled, "L1");
        _;
    }

    // Constructor to initialize the owner
    constructor() {
        _owner = msg.sender; // Set the contract deployer as the owner
        emit OwnershipTransferred(address(0), _owner); // Emit the ownership transfer event
    }

    // Function to get the current owner
    function owner() public view returns (address) {
        return _owner;
    }

    // Function to transfer ownership to a new address
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // Function to enable part of the logic
    function enableContract() public onlyOwner {
        contractEnabled = true;
        emit ContractStatusChanged(true);
    }

    // Function to disable part of the logic
    function disableContract() public onlyOwner {
        contractEnabled = false;
        emit ContractStatusChanged(false);
    }
}
