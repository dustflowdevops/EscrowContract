// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "DealLocalInteractManager.sol";

contract DealEditManager is DealLocalInteractManager 
{
    event DealBecomeTwoSided(bytes32 indexed id, address indexed  initiator, address indexed  counterparty, address mediator);
    
    event EditDealMediatorRequestCreated(uint indexed id,  bytes32 indexed dealId, address indexed newMediator, address sender);
    event EditDealMediatorRequestUpdated(uint indexed reid,  address sender,  bool signedByInitiator,   bool signedByCounterparty, bool rejected);

    event EditDealExpirationRequestCreated(bytes32 indexed id, address indexed  initiator, address indexed  counterparty, address mediator, address sender, uint requestId);
    event EditDealExpirationRequestUpdated(uint indexed id, address sender, bool signedInititor, bool signedCounterparty, bool signedMediator, bool rejected);
    event EditedDealExpiration(uint indexed Id, bytes32 indexed dealId,
    address initiator, address counterparty, address mediator, address sender, uint newExpirationDate, MediatorAction mediatorActionOnExpiration);

    uint public totalEditExpirationRequests = 0;
    uint public totalEditDealMediatorRequests = 0;

    mapping(uint => EditDealExpiratation) public editDealExpirationRequests;
    mapping(uint => EditDealMediator) public editDealMediatorRequests;

    constructor(uint256 _depositCommissionPercent, address _commissionRecipient) 
    DealLocalInteractManager(_depositCommissionPercent, _commissionRecipient) {   
    }

    //Get deal mediator edit request
    function getEditDealMediator(uint id) public view returns (EditDealMediator memory)
    {
        return editDealMediatorRequests[id];
    }

    //Sign or reject request to set mediator
    function signEditDealMediatorRequest(uint requestId, bool reject) public returns (bool) {
        EditDealMediator storage request = editDealMediatorRequests[requestId];
        Deal storage deal = deals[request.dealId];

        require(deal.initiator == msg.sender || deal.counterparty == msg.sender, 
            "D5");

        if (reject) {
            request.rejected = true;

            emit EditDealMediatorRequestUpdated(requestId, msg.sender, request.singedByInitiator, request.signedByCounterparty, true);
            return false;
        }

        require(deal.mediator == address(0), "C3.1");    

        if (deal.initiator == msg.sender) {
            request.singedByInitiator = true;
        }

        if (deal.counterparty == msg.sender) {
            request.signedByCounterparty = true;
        }

        if (request.singedByInitiator && request.signedByCounterparty) {
            deal.mediator = request.mediator;

            emit JoinedToDealAsMediator(request.mediator, request.dealId);
            return true;
        }

        emit EditDealMediatorRequestUpdated(requestId, msg.sender, request.singedByInitiator, request.signedByCounterparty, false);
        return false;
    }

    //Create request to set mediator
    function createEditDealMediatorRequest(bytes32 dealId, address payable newMediator) public returns (uint) {
        Deal storage deal = deals[dealId];

        require(deal.initiator == msg.sender || deal.counterparty == msg.sender, 
            "D5");
        
        require(newMediator != address(0), "C1");
        require(deal.mediator == address(0), "C3.1");

        EditDealMediator memory request = EditDealMediator({
            dealId: dealId,
            mediator: newMediator,
            singedByInitiator: false,
            signedByCounterparty: false,
            rejected: false
        });

        uint requestId = totalEditDealMediatorRequests;
        editDealMediatorRequests[requestId] = request;
        totalEditDealMediatorRequests++;

        emit EditDealMediatorRequestCreated(requestId, dealId, newMediator, msg.sender);

        return requestId;
    }

    //Get deal expiration edit request
    function getEditDealExpiratation(uint id) public view returns (EditDealExpiratation memory)
    {
        return editDealExpirationRequests[id];
    }

    //Create request to edit deal time limit settings 
    function createDealEditExpiration(bytes32 dealId, uint newExpirationDate, MediatorAction newMediatorActionOnExpiration) public returns (uint) 
    {
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender || deal.initiator == msg.sender || deal.mediator == msg.sender,"D5");
        DealContract.requireCanEdit(deal);
        require(newExpirationDate == DealContract.NOEXPIRATIONDATE || newExpirationDate <= block.timestamp,"D1.1"); 

        EditDealExpiratation memory request = EditDealExpiratation({
            dealId: dealId,
            expirationDate: newExpirationDate,
            mediatorActionOnExpiration: newMediatorActionOnExpiration,
            singedByInitiator:  false,
            signedByCounterparty: false,
            signedByMediator :false,
            rejected: false
        });

        uint id = totalEditExpirationRequests;

        editDealExpirationRequests[id] = request;

        emit EditDealExpirationRequestCreated(dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender, id);

        totalEditExpirationRequests++;

        return id;
    }

    //Sign or reject request to edit deal time limit settings 
    function signDealEditExpiration(uint id, bool reject) public returns (bool) {
        EditDealExpiratation storage request = editDealExpirationRequests[id];
        Deal storage deal = deals[request.dealId];

        require(deal.counterparty == msg.sender || deal.initiator == msg.sender || deal.mediator == msg.sender, "D5");
        DealContract.requireCanEdit(deal);

        if (reject) {
            request.rejected = true;

            emit EditDealExpirationRequestUpdated(id, msg.sender, request.singedByInitiator, request.signedByCounterparty, request.signedByMediator, true);
            
            return false;
        }

        require(request.expirationDate == DealContract.NOEXPIRATIONDATE || request.expirationDate <= block.timestamp, "D1.1"); 

        if (deal.initiator == msg.sender) {
            request.singedByInitiator = true;
        }
        if (deal.counterparty == msg.sender) {
            request.signedByCounterparty = true;
        }
        if (deal.mediator == msg.sender) {
            request.signedByMediator = true;
        }

        if (request.singedByInitiator && request.signedByCounterparty && request.signedByMediator) {
            deal.expirationDate = request.expirationDate;
            deal.mediatorActionOnExpiration = request.mediatorActionOnExpiration;

            emit EditedDealExpiration(id, request.dealId, deal.initiator, deal.counterparty, deal.mediator, msg.sender, request.expirationDate, request.mediatorActionOnExpiration);

            return true;
        }

        emit EditDealExpirationRequestUpdated(id, msg.sender, request.singedByInitiator, request.signedByCounterparty, request.signedByMediator, false);
        return false;
    }


    //Made deal two sided by deposit tokens from counterparty, 
    function payUpMadeDealTwoSided(bytes32 dealId, address tokenAdress, uint amount, uint PRC_mediatorFee) public payable returns (bool){
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender, "D5");
        DealContract.requireCanEdit(deal);  
        require(deal.isTwoSided == false, "D2.2");

        uint balance = balanceOf(msg.sender, tokenAdress);

        if(balance < amount)
        {
            deposit(tokenAdress, amount - balance); // Deposit all rest money to create deal
        }

        removeBalanceFrom(msg.sender,tokenAdress, amount);

        deal.isTwoSided = true;
        deal.counterpartyTokenAddress = tokenAdress;
        deal.counterpartyCreateAmount = amount;
        deal.counterpartyCurrentAmount = amount;
        deal.PRC_CounterpartyMediatorFee = PRC_mediatorFee;

        emit DealBecomeTwoSided(dealId, deal.initiator, deal.counterparty, deal.mediator);

        return true;
    }

    //Made deal two sided by deposit tokens from counterparty
    function madeDealTwoSided(bytes32 dealId, address tokenAdress, uint amount, uint PRC_mediatorFee) public  returns (bool){
        Deal storage deal = deals[dealId];

        require(deal.counterparty == msg.sender, "D5");
        DealContract.requireCanEdit(deal);  
        require(deal.isTwoSided == false, "D2.2");

        require(balanceOf(msg.sender, tokenAdress) >= amount, "T1");
        removeBalanceFrom(msg.sender,tokenAdress, amount);

        if(PRC_mediatorFee != 0)
        {
            require(deal.mediator != address(0), "D1.1");
        }  

        uint balance = balanceOf(msg.sender, tokenAdress);

        if(balance < amount)
        {
            deposit(tokenAdress, amount - balance); // Deposit all rest money to create deal
        }

        removeBalanceFrom(msg.sender,tokenAdress, amount);

        deal.isTwoSided = true;
        deal.counterpartyTokenAddress = tokenAdress;
        deal.counterpartyCreateAmount = amount;
        deal.counterpartyCurrentAmount = amount;
        deal.PRC_CounterpartyMediatorFee = PRC_mediatorFee;

        emit DealBecomeTwoSided(dealId, deal.initiator, deal.counterparty, deal.mediator);

        return true;
    }
}

struct EditDealExpiratation{
    bytes32 dealId;

    uint256 expirationDate; // The date when the deal expires (timestamp)
    MediatorAction mediatorActionOnExpiration; // Action to be applied after expiration

    bool singedByInitiator;
    bool signedByCounterparty;
    bool signedByMediator;

    bool rejected;
}

struct EditDealMediator{
    bytes32 dealId;

    address payable mediator; 

    bool singedByInitiator;
    bool signedByCounterparty;

    bool rejected;
}
