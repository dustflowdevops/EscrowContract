// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "Percent.sol";

// Enum for the mediator action types
enum MediatorAction {
    backToUsers,           // Action: return to the users
    closeToInitiator,      // Close towards the initiator
    closeToCounterparty,   // Close towards the counterparty
    closeToMediator,       // Close towards the mediator
    closeToPlatform,       // Close towards the platform (0 address)
    none                   // Default empty status
}

enum DealStatus {
    Completed,
    Canceled,
    UnFinished
}

// Deal structures
struct Deal {
    address payable initiator; // The party that initiates the deal
    address payable counterparty; // The counterparty in the deal
    address payable mediator; // The mediator in the deal

    DealStatus status;

    bool isTwoSided; // Inititor and counterpart both deposit money

    bool isSignedByCounterparty; // Flag is signed by counterparty, auto if one side transfer

    uint256 initiatorCreateAmount; // The amount of tokens provided by the initiator
    uint256 counterpartyCreateAmount; // The amount of tokens provided by the counterparty

    uint256 initiatorCurrentAmount; // The current balance of the initiator
    uint256 counterpartyCurrentAmount; // The current balance of the counterparty

    uint256 PRC_InitiatorMediatorFee; // The fee percentage from the counterparty's tokens for the contract
    uint256 PRC_CounterpartyMediatorFee; // The mediator's fee percentage from the counterparty's tokens

    address initiatorTokenAddress; // The token address used by the initiator, if applicable
    address counterpartyTokenAddress; // The token address used by the counterparty, if applicable

    uint256 expirationDate; // The date when the deal expires (timestamp)
    MediatorAction mediatorActionOnExpiration; // Action to be applied after expiration
}

library DealContract {
    uint256 public constant NOEXPIRATIONDATE = 0; // Value of expiration date without limit
    uint256 public constant MaxProcent = Percent.MAXVALUE; // Maximum allowed percentage (100%)

    // Function to generate the hash (bytes32) of the Deal struct
    function requireCanEdit(Deal memory deal) public view {
        require(deal.expirationDate == NOEXPIRATIONDATE || deal.expirationDate < block.timestamp, "D1");
        require(deal.isSignedByCounterparty, "D2");
        require(deal.status == DealStatus.UnFinished, "D3");
    }

    // Constructor to initialize and validate the Deal struct
    function createDeal(
        address payable _initiator,
        address payable _counterparty,
        address payable _mediator,

        uint256 _initiatorCreateAmount,
        uint256 _counterpartyCreateAmount,

        uint256 _PRC_MediatorFeeInititor,
        uint256 _PRC_MediatorFeeCounterparty,
        
        address _initiatorTokenAddress,
        address _counterpartyTokenAddress,

        uint256 _expirationDate,
        MediatorAction _mediatorActionOnExpiration
    ) public view returns (Deal memory) {

        // Validation checks
        require(_initiator != address(0), "C1"); // Initiator cannot be address(0)
        require(_counterparty != address(0), "C1"); // Counterparty cannot be address(0)
        require(_expirationDate == NOEXPIRATIONDATE || _expirationDate <= block.timestamp, "D1.1"); //Data cant be created already expired

        // If the mediator is address(0), set its fee percentages to 0
        if (_mediator == address(0)) {
            require(_PRC_MediatorFeeInititor == 0 && _PRC_MediatorFeeCounterparty == 0, "C1.1");
        }

        // Ensure that the mediator, initiator, and counterparty are distinct addresses
        require(_mediator != _initiator, "C3");
        require(_mediator != _counterparty, "C3");
        require(_initiator != _counterparty, "C3");

        // Ensure the sum of the contract and mediator's percentage does not exceed 100%
        uint256 totalContractFee = _PRC_MediatorFeeInititor;
        uint256 totalMediatorFee = _PRC_MediatorFeeCounterparty;
        require(totalContractFee <= MaxProcent, "C5");
        require(totalMediatorFee <= MaxProcent, "C5");

        require(_initiatorCreateAmount > 0, "C5");

        bool isTwoSided = _counterpartyCreateAmount > 0;

        if(!isTwoSided)
        {
            require(_counterpartyTokenAddress == address(0) && 
            _PRC_MediatorFeeCounterparty == 0, "C1.1");
        }

        // Create a Deal struct and generate its hash
        Deal memory newDeal = Deal({
            initiator: _initiator,
            counterparty: _counterparty,
            mediator: _mediator,

            isSignedByCounterparty: !isTwoSided,

            status: DealStatus.UnFinished,

            isTwoSided: isTwoSided,

            initiatorCreateAmount: _initiatorCreateAmount,
            counterpartyCreateAmount: _counterpartyCreateAmount,
            initiatorCurrentAmount: _initiatorCreateAmount,
            counterpartyCurrentAmount: _counterpartyCreateAmount,

            PRC_InitiatorMediatorFee: _PRC_MediatorFeeInititor,
            PRC_CounterpartyMediatorFee: _PRC_MediatorFeeCounterparty,
 
            initiatorTokenAddress: _initiatorTokenAddress,
            counterpartyTokenAddress: _counterpartyTokenAddress,

            expirationDate: _expirationDate,
            mediatorActionOnExpiration: _mediatorActionOnExpiration
        });

        return newDeal;
    }

    // Function to generate the hash (bytes32) of the Deal struct
    function createDealId(Deal memory deal, uint totalCreated) public view  returns (bytes32) {
        // Hashing the entire struct using keccak256, including the new fields for expiration
        return keccak256(abi.encodePacked(
            deal.initiator,
            deal.counterparty,
            deal.mediator,
            deal.initiatorCreateAmount,
            deal.counterpartyCreateAmount,
            deal.initiatorCurrentAmount,
            deal.counterpartyCurrentAmount,
            deal.PRC_InitiatorMediatorFee,
            deal.PRC_CounterpartyMediatorFee,
            deal.initiatorTokenAddress,
            deal.counterpartyTokenAddress,
            deal.expirationDate,
            deal.mediatorActionOnExpiration,
            block.timestamp,
            totalCreated
        ));
    }
}
