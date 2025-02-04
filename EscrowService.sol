// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "DealEditManager.sol";

contract EscrowService is DealEditManager 
{
    constructor(uint256 _depositCommissionPercent, address _commissionRecipient) 
    DealEditManager(_depositCommissionPercent, _commissionRecipient) {   
    }
}