// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LockableContract is Ownable {

    // States for deposit logic enable/disable
    bool public contractEnabled = true;

    // Events to track status changes and ownership
    event ContractStatusChanged(bool status);
    event ContractEnabled(address indexed by);
    event ContractDisabled(address indexed by);

    // Modifier to ensure that part of logic are allowed
    modifier whenContractEnabled() {
        require(contractEnabled, "L1");
        _;
    }

    constructor() Ownable(msg.sender) {}

    // Function to enable part of logic
    function enableContract() public onlyOwner {
        contractEnabled = true;
        emit ContractStatusChanged(true);
        emit ContractEnabled(msg.sender);
    }

    // Function to disable part of logic
    function disableContract() public onlyOwner {
        contractEnabled = false;
        emit ContractStatusChanged(false);
        emit ContractDisabled(msg.sender);
    }
}
