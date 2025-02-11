// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "Deal.sol";
import "WalletContract.sol";

contract DealCreationManager is WalletContract {
    // Storage for deals by hash
    mapping(bytes32 => Deal) public deals;

    uint256 public totalDeals = 0; // Track total number of deals
    uint256 public totalCompletedDeals = 0; // Track number of completed deals

    event DealRequestCreated(bytes32 indexed id, address indexed  initiator, address indexed  counterparty, address mediator);
    
    event JoinedToDealAsMediator(address indexed mediator, bytes32 dealId);
    
    event DealCreated(bytes32 indexed id, address indexed  initiator, address indexed  counterparty, address mediator);
    event DealCanceled(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,  address mediator,address sender);
    event DealCompited(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,address mediator,address sender);

    event AddDepositByInitiator(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,
     address mediator, uint amount);
    event AddDepositByCounterparty(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,
     address mediator, uint amount);

    event TransferToInitiator(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,
     address mediator, address sender, uint amount, uint fee);
    event TransferToCounterparty(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,
     address mediator, address sender, uint amount, uint fee);

    event GivebackToInitiator(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,
     address mediator, address sender, uint amount, uint fee);
    event GivebackToCounterparty(bytes32 indexed id, address indexed  initiator, address indexed  counterparty,
     address mediator, address sender, uint amount, uint fee);

    event TransferToFromDeal(bytes32 indexed id, address indexed initiator, address indexed counterparty,
     address mediator, address sender, address target, uint amountInitiator, uint amountCounterparty, uint feeInitiator, uint feeCounterparty);

    constructor(uint256 depositCommissionPercent, address commissionRecipient) WalletContract(depositCommissionPercent, commissionRecipient) {   
    }
   
    //Reject sided deal and auto withdraw founds 
    function withdrawRejectSidedDeal(bytes32 dealId) public returns (bool){
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.initiator == msg.sender, "D5");
        require(deal.isSignedByCounterparty == false && deal.isTwoSided, "D2.1");
        require(deal.status == DealStatus.UnFinished, "D3");

        withdrawFromContractTo(deal.initiator, deal.initiatorTokenAddress, deal.initiatorCurrentAmount);

        emit DealCanceled(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender);

        return true;
    }

    //Reject sided deal 
    function rejectSidedDeal(bytes32 dealId) public returns (bool){
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.initiator == msg.sender, "D5");
        require(deal.isTwoSided, "D3.1");
        require(deal.isSignedByCounterparty == false, "D2.1");
        require(deal.status == DealStatus.UnFinished, "D3");

        addBalanceTo(deal.initiator,deal.initiatorTokenAddress,deal.initiatorCurrentAmount);

        emit DealCanceled(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender);

        return true;
    }

    //Sign deal as counterparty by inner balance, if "T1" require to payUp
    function payUpCounterpartyAcceptSidedDeal(bytes32 dealId) public payable returns (bool){
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender, "D5");
        require(deal.isTwoSided, "D3.1");
        require(deal.isSignedByCounterparty == false, "D2.1");
        require(deal.status == DealStatus.UnFinished, "D3");

        uint balance = balanceOf(msg.sender, deal.counterpartyTokenAddress);

        if(balance < deal.counterpartyCurrentAmount)
        {
            deposit(deal.counterpartyTokenAddress, deal.counterpartyCreateAmount - balance); // Deposit all rest money to create deal
        }

        removeBalanceFrom(msg.sender,deal.counterpartyTokenAddress, deal.counterpartyCreateAmount);

        deal.isSignedByCounterparty = true;

        emit DealCreated(dealId, deal.initiator, deal.counterparty, deal.mediator);

        if(deal.mediator != address(0))
        {
            emit JoinedToDealAsMediator(deal.mediator, dealId);
        }

        return true;
    }

    //Sign deal as counterparty by inner balance
    function counterpartyAcceptSidedDeal(bytes32 dealId) public returns (bool){
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender, "D5");
        require(deal.isTwoSided, "D3.1");
        require(deal.isSignedByCounterparty == false, "D2.1");
        require(deal.status == DealStatus.UnFinished, "D3");

        require(balanceOf(msg.sender, deal.counterpartyTokenAddress) >= deal.counterpartyCreateAmount, "T1");

        removeBalanceFrom(msg.sender,deal.counterpartyTokenAddress, deal.counterpartyCreateAmount);

        deal.isSignedByCounterparty = true;

        emit DealCreated(dealId, deal.initiator, deal.counterparty, deal.mediator);

        if(deal.mediator != address(0))
        {
            emit JoinedToDealAsMediator(deal.mediator, dealId);
        }

        return true;
    }

    // Create double sided deal by inner balance, if "T1" require to payUp
    function payUpCreateSidedDeal(
        address payable counterparty,
        address payable mediator,

        uint256 initiatorCreateAmount,
        uint256 counterpartyCreateAmount,

        uint256 PRCMediatorFeeInititor,
        uint256 PRCMediatorFeeCounterparty,
        
        address initiatorTokenAddress,
        address counterpartyTokenAddress,

        uint256 expirationDate,
        MediatorAction mediatorActionOnExpiration
    ) public whenContractEnabled payable returns (bytes32) {
       uint balance = balanceOf(msg.sender, initiatorTokenAddress);

        if(balance < initiatorCreateAmount)
        {
            deposit(initiatorTokenAddress, initiatorCreateAmount - balance); // Deposit all rest money to create deal
        }

        removeBalanceFrom(msg.sender,initiatorTokenAddress,initiatorCreateAmount);

        Deal memory newDeal = DealContract.createDeal(
            payable(msg.sender),
            counterparty,
            mediator,
            initiatorCreateAmount,
            counterpartyCreateAmount,
            PRCMediatorFeeInititor,
            PRCMediatorFeeCounterparty,
            initiatorTokenAddress,
            counterpartyTokenAddress,
            expirationDate,
            mediatorActionOnExpiration
        );

        // Generate the deal hash
        bytes32 dealId = DealContract.createDealId(newDeal,totalDeals);
        totalDeals++;

        deals[dealId] = newDeal;

        // Emit an event
        emit DealRequestCreated(dealId, msg.sender, counterparty, mediator);

        return dealId;
    }

   // Create double sided deal by inner balance
    function createSidedDeal(
        address payable counterparty,
        address payable mediator,

        uint256 initiatorCreateAmount,
        uint256 counterpartyCreateAmount,

        uint256 PRCMediatorFeeInititor,
        uint256 PRCMediatorFeeCounterparty,
        
        address initiatorTokenAddress,
        address counterpartyTokenAddress,

        uint256 expirationDate,
        MediatorAction mediatorActionOnExpiration
    ) public whenContractEnabled returns (bytes32) {
        require(balanceOf(msg.sender, initiatorTokenAddress) >= initiatorCreateAmount, "T1");

        removeBalanceFrom(msg.sender,initiatorTokenAddress,initiatorCreateAmount);

        Deal memory newDeal = DealContract.createDeal(
            payable(msg.sender),
            counterparty,
            mediator,
            initiatorCreateAmount,
            counterpartyCreateAmount,
            PRCMediatorFeeInititor,
            PRCMediatorFeeCounterparty,
            initiatorTokenAddress,
            counterpartyTokenAddress,
            expirationDate,
            mediatorActionOnExpiration
        );

        // Generate the deal hash
        bytes32 dealId = DealContract.createDealId(newDeal,totalDeals);
        totalDeals++;

        deals[dealId] = newDeal;

        // Emit an event
        emit DealRequestCreated(dealId, msg.sender, counterparty, mediator);

        return dealId;
    }

    // Create deal by inner balance, if "T1" require to payUp
    function payUpCreateDeal(
        address payable counterparty,
        address payable mediator,
        uint256 amount,
        uint256 PRCMediatorFee,
        address tokenAddress,
        uint256 expirationDate,
        MediatorAction mediatorActionOnExpiration
    ) public whenContractEnabled payable returns (bytes32) {
        uint balance = balanceOf(msg.sender, tokenAddress);

        if(balance < amount)
        {
            deposit(tokenAddress, amount - balance); // Deposit all rest money to create deal
        }

        removeBalanceFrom(msg.sender,tokenAddress, amount);

        Deal memory newDeal = DealContract.createDeal(
            payable(msg.sender),
            counterparty,
            mediator,
            amount,
            0,
            PRCMediatorFee,
            0,
            tokenAddress,
            address(0),
            expirationDate,
            mediatorActionOnExpiration
        );

        // Generate the deal hash
        bytes32 dealId = DealContract.createDealId(newDeal,totalDeals);
        totalDeals++;

        deals[dealId] = newDeal;

        // Emit an event
        emit DealCreated(dealId, msg.sender, counterparty, mediator);

        if(mediator != address(0))
        {
            emit JoinedToDealAsMediator(mediator, dealId);
        }

        return dealId;
    }

    // Create deal by inner balance
    function createDeal(
        address payable counterparty,
        address payable mediator,
        uint256 amount,
        uint256 PRCMediatorFee,
        address tokenAddress,
        uint256 expirationDate,
        MediatorAction mediatorActionOnExpiration
    ) public whenContractEnabled returns (bytes32) {
        require(balanceOf(msg.sender, tokenAddress) >= amount, "T1");

        removeBalanceFrom(msg.sender,tokenAddress, amount);

        Deal memory newDeal = DealContract.createDeal(
            payable(msg.sender),
            counterparty,
            mediator,
            amount,
            0,
            PRCMediatorFee,
            0,
            tokenAddress,
            address(0),
            expirationDate,
            mediatorActionOnExpiration
        );

        // Generate the deal hash
        bytes32 dealId = DealContract.createDealId(newDeal,totalDeals);
        totalDeals++;

        deals[dealId] = newDeal;

        // Emit an event
        emit DealCreated(dealId, msg.sender, counterparty, mediator);
        
        if(mediator != address(0))
        {
            emit JoinedToDealAsMediator(mediator, dealId);
        }

        return dealId;
    }

    // Function to retrieve a deal by its ID
    function getDeal(bytes32 dealId) public view returns (Deal memory) {
        return deals[dealId];
    }
}
