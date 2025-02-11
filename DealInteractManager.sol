// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "DealCreationManager.sol";

contract DealInteractManager is DealCreationManager 
{
    constructor(uint256 _depositCommissionPercent, address _commissionRecipient) 
    DealCreationManager(_depositCommissionPercent, _commissionRecipient) {   
    }

    //MAIN

    // Executes specific actions defined for the deal after the expiration date
    function executeActionsAfterExpiration(bytes32 dealId, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.initiator == msg.sender || deal.mediator == msg.sender, "D5");
        require(deal.isSignedByCounterparty, "D2");
        require(deal.status == DealStatus.UnFinished, "D3");        
        require(deal.expirationDate <= block.timestamp, "D1.2");

        MediatorAction action = deal.mediatorActionOnExpiration;

        uint depositInitiator = deal.initiatorCurrentAmount;
        address tokenIntitiator = deal.initiatorTokenAddress;

        uint depositCounterparty = deal.counterpartyCurrentAmount;
        address tokenCounterparty = deal.counterpartyTokenAddress;

        uint PRC_feeInitatior = deal.PRC_InitatorMediatorFee;
        uint PRC_feeCounterparty = deal.PRC_CounterpartyMediatorFee;

        uint amountToMediatorInitiator = Percent.applyToNumber(depositInitiator, PRC_feeInitatior);
        uint amountToMediatorCounterparty = Percent.applyToNumber(depositCounterparty, PRC_feeCounterparty);

        if(action == MediatorAction.backToUsers)
        {
            invokeAddBalanceTo(local, deal.initiator, tokenIntitiator, depositInitiator - amountToMediatorInitiator);
            invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

            invokeAddBalanceTo(local, deal.counterparty, tokenCounterparty, depositCounterparty - amountToMediatorCounterparty);
            invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);

            emit GivebackToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator, 
            msg.sender, depositInitiator, amountToMediatorInitiator); 
            emit GivebackToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator, 
            msg.sender, depositCounterparty, amountToMediatorCounterparty);
        }

        if(action == MediatorAction.closeToCounterparty)
        {
            invokeAddBalanceTo(local, deal.counterparty, tokenIntitiator, depositInitiator - amountToMediatorInitiator);
            invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

            invokeAddBalanceTo(local, deal.counterparty, tokenCounterparty, depositCounterparty - amountToMediatorCounterparty);
            invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);
        
            emit TransferToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator,
            msg.sender, depositInitiator,amountToMediatorInitiator); 
            emit GivebackToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator,
            msg.sender, depositCounterparty,amountToMediatorCounterparty);
        }

        if(action == MediatorAction.closeToInitiator)
        {
            invokeAddBalanceTo(local, deal.initiator, tokenIntitiator, depositInitiator - amountToMediatorInitiator);
            invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

            invokeAddBalanceTo(local, deal.initiator, tokenCounterparty, depositCounterparty - amountToMediatorCounterparty);
            invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);
            
            emit GivebackToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator,
            msg.sender, depositInitiator, amountToMediatorInitiator); 
            emit TransferToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator,
            msg.sender, depositCounterparty, amountToMediatorCounterparty);
        }

        if(action == MediatorAction.closeToMediator)
        {
            invokeAddBalanceTo(local, deal.mediator, tokenIntitiator,depositInitiator);
            invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, depositCounterparty);

            emit TransferToFromDeal(dealId, deal.initiator, deal.counterparty, deal.mediator,
            msg.sender, deal.mediator, amountToMediatorInitiator, amountToMediatorCounterparty, 0, 0);   
        }

        if(action == MediatorAction.closeToPlatform)
        {
            invokeAddBalanceTo(local, commissionRecipient, tokenIntitiator,depositInitiator - amountToMediatorInitiator);
            invokeAddBalanceTo(local, commissionRecipient, tokenCounterparty, depositCounterparty - amountToMediatorCounterparty);

            invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);
            invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);

            emit TransferToFromDeal(dealId, deal.initiator, deal.counterparty, deal.mediator,
            msg.sender, commissionRecipient, amountToMediatorInitiator, amountToMediatorCounterparty,
            amountToMediatorInitiator, amountToMediatorCounterparty);  
        }

        deal.status = DealStatus.Canceled;

        emit DealCanceled(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender);

        return true; 
    }

    // Cancels an active deal, returning funds to the respective parties 
    function cancelDeal(bytes32 dealId, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.mediator == msg.sender, "D5");
        DealContract.requireCanEdit(deal);  

        uint depositInitiator = deal.initiatorCurrentAmount;
        address tokenIntitiator = deal.initiatorTokenAddress;

        uint depositCounterparty = deal.counterpartyCurrentAmount;
        address tokenCounterparty = deal.counterpartyTokenAddress;

        uint PRC_feeInitatior = deal.PRC_InitatorMediatorFee;
        uint PRC_feeCounterparty = deal.PRC_CounterpartyMediatorFee;

        uint amountToMediatorInitiator = Percent.applyToNumber(depositInitiator, PRC_feeInitatior);
        uint amountToMediatorCounterparty = Percent.applyToNumber(depositCounterparty, PRC_feeCounterparty);

        invokeAddBalanceTo(local, deal.initiator, tokenIntitiator, depositInitiator - amountToMediatorInitiator);
        invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

        invokeAddBalanceTo(local, deal.counterparty, tokenCounterparty, depositCounterparty - depositCounterparty);
        invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);

        deal.status = DealStatus.Canceled;

        emit GivebackToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator, 
        msg.sender, depositInitiator, amountToMediatorInitiator); 
        emit GivebackToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator,
        msg.sender, depositCounterparty,amountToMediatorCounterparty); 
        emit DealCanceled(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender);

        return true; 
    }

    // Marks the deal as completed and executes final terms
    function completeDeal(bytes32 dealId, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.initiator == msg.sender || deal.mediator == msg.sender, "D5");
        DealContract.requireCanEdit(deal);  

        uint depositInitiator = deal.initiatorCurrentAmount;
        address tokenIntitiator = deal.initiatorTokenAddress;

        uint depositCounterparty = deal.counterpartyCurrentAmount;
        address tokenCounterparty = deal.counterpartyTokenAddress;

        uint PRC_feeInitatior = deal.PRC_InitatorMediatorFee;
        uint PRC_feeCounterparty = deal.PRC_CounterpartyMediatorFee;

        uint amountToMediatorInitiator = Percent.applyToNumber(depositInitiator, PRC_feeInitatior);
        uint amountToMediatorCounterparty = Percent.applyToNumber(depositCounterparty, PRC_feeCounterparty);

        invokeAddBalanceTo(local, deal.counterparty, tokenIntitiator, depositInitiator - amountToMediatorInitiator);
        invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

        invokeAddBalanceTo(local, deal.initiator, tokenCounterparty, depositCounterparty - depositCounterparty);
        invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);

        deal.status = DealStatus.Completed;

        emit TransferToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator,
        msg.sender, depositCounterparty,amountToMediatorCounterparty);    
        emit TransferToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator, 
        msg.sender, depositInitiator,amountToMediatorInitiator);
        emit DealCompited(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender);

        totalCompletedDeals++;

        return true; 
    }

    //DEPOSIT

    // Allows the initiator to make an additional deposit
    function addDepositByInitiator(bytes32 dealId, uint256 amount, bool local) public payable returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.initiator == msg.sender, "D5");
        DealContract.requireCanEdit(deal); 

        uint balance = balanceOf(msg.sender, deal.initiatorTokenAddress);

        if(local)
        {
            require(balance >= amount, "T1");
        }
        else
        {
            if(balance < amount)
            {
                deposit(deal.initiatorTokenAddress, amount - balance);
            }
        }

        removeBalanceFrom(msg.sender,deal.initiatorTokenAddress, amount);

        deal.initiatorCurrentAmount += amount;

        emit AddDepositByInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator, amount);

        return true; 
    }

    // Allows the counterparty to make an additional deposit
    function addDepositByCounterparty(bytes32 dealId, uint256 amount, bool local) public payable returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender, "D5");
        DealContract.requireCanEdit(deal); 

        uint balance = balanceOf(msg.sender, deal.counterpartyTokenAddress);

        if(local)
        {
            require(balance >= amount, "T1");
        }
        else
        {
            if(balance < amount)
            {
                deposit(deal.counterpartyTokenAddress, amount - balance);
            }
        }

        removeBalanceFrom(msg.sender,deal.counterpartyTokenAddress, amount);

        deal.counterpartyCurrentAmount += amount;

        emit AddDepositByCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator, amount);

        return true; 
    }

    //TRANSFER

    // Allows the transfer part of deal founds
    function transferToCounterparty(bytes32 dealId, uint256 amount, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.initiator == msg.sender || deal.mediator == msg.sender, "D5");
        DealContract.requireCanEdit(deal); 

        require(deal.initiatorCurrentAmount < amount, "T1");

        deal.initiatorCurrentAmount -= amount;

        address tokenIntitiator = deal.initiatorTokenAddress;
        uint PRC_feeInitatior = deal.PRC_InitatorMediatorFee;
        uint amountToMediatorInitiator = Percent.applyToNumber(amount, PRC_feeInitatior);

        invokeAddBalanceTo(local, deal.counterparty, tokenIntitiator, amount- amountToMediatorInitiator);
        invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

        emit TransferToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender, amount, amountToMediatorInitiator);

        return true; 
    }

    // Allows the transfer part of deal founds
    function transferToInitiator(bytes32 dealId, uint256 amount, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.mediator == msg.sender, "D5");
        DealContract.requireCanEdit(deal); 

        require(deal.counterpartyCurrentAmount < amount, "T1");

        deal.counterpartyCurrentAmount -= amount;

        address tokenCounterparty = deal.counterpartyTokenAddress;
        uint PRC_feeCounterparty = deal.PRC_CounterpartyMediatorFee;
        uint amountToMediatorCounterparty = Percent.applyToNumber(amount, PRC_feeCounterparty);

        invokeAddBalanceTo(local, deal.initiator, tokenCounterparty, amount- amountToMediatorCounterparty);
        invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);

        emit TransferToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender, amount, amountToMediatorCounterparty);

        return true; 
    }

    //GIVEBACK

    // Allows the transfer part of deal founds
    function givebackToConunterparty(bytes32 dealId, uint256 amount, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.initiator == msg.sender || deal.mediator == msg.sender, "D5");
        DealContract.requireCanEdit(deal); 

        require(deal.counterpartyCurrentAmount < amount, "T1");

        deal.counterpartyCurrentAmount -= amount;

        address tokenCounterparty = deal.counterpartyTokenAddress;
        uint PRC_feeCounterparty = deal.PRC_CounterpartyMediatorFee;
        uint amountToMediatorCounterparty = Percent.applyToNumber(amount, PRC_feeCounterparty);

        invokeAddBalanceTo(local, deal.counterparty, tokenCounterparty, amount- amountToMediatorCounterparty);
        invokeAddBalanceTo(local, deal.mediator, tokenCounterparty, amountToMediatorCounterparty);

        emit GivebackToCounterparty(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender, amount, amountToMediatorCounterparty);

        return true; 
    }

    // Allows the transfer part of deal founds
    function givebackToInitiator(bytes32 dealId, uint256 amount, bool local) public returns (bool) {
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.mediator == msg.sender,"D5");
        DealContract.requireCanEdit(deal); 

        require(deal.initiatorCurrentAmount < amount, "T1");

        deal.initiatorCurrentAmount -= amount;

        address tokenIntitiator = deal.initiatorTokenAddress;
        uint PRC_feeInitatior = deal.PRC_InitatorMediatorFee;
        uint amountToMediatorInitiator = Percent.applyToNumber(amount, PRC_feeInitatior);

        invokeAddBalanceTo(local, deal.initiator, tokenIntitiator, amount- amountToMediatorInitiator);
        invokeAddBalanceTo(local, deal.mediator, tokenIntitiator, amountToMediatorInitiator);

        emit GivebackToInitiator(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender, amount, amountToMediatorInitiator);

        return true; 
    }

    function invokeAddBalanceTo(bool local, address to, address token, uint amount) internal returns (bool)
    {
        if(local)
        {
           return  addBalanceTo(to, token, amount);
        }
        else
        {
            return withdrawFromContractTo(to, token, amount);
        }
    }
}