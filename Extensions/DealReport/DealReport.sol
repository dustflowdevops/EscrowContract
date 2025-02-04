// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.17;

import "DealCreationManager.sol";

// Contract for handling reviews of deals
contract DealReview {
    // Event emitted when a review is given
    event ReviewGiven(
        address indexed from,          // From whom the review is
        address indexed to,            // To whom the review is
        bytes32 indexed dealId,        // Deal ID
        string comment,                // Review text
        address initiatior,
        address counterparty,
        address mediator
    );

    // Mapping of deal IDs to reviews
    mapping(bytes32 => mapping(address => mapping(address => string))) public reviews; // dealId -> from -> to -> Review

    // Reference to the DealContract to interact with it
    DealCreationManager public dealContract;
    address public dealContractAddress;

    // Constructor to set the DealContract address
    constructor(address _dealContractAddress) {
        dealContract = DealCreationManager(_dealContractAddress);
        dealContractAddress = _dealContractAddress;
    }

    // Function to leave a review
    function leaveReview(
        bytes32 dealId,                // The deal ID
        address _to,                 // To whom the review is left (another participant)
        string memory _comment        // Review text
    ) public {
        Deal memory deal = dealContract.getDeal(dealId);

        require(deal.isCompleted || deal.isCanceled, "D4");
        
        require(bytes(_comment).length > 0, "C1");
        require(_to != address(0), "C1");
        require(_to != msg.sender, "C3");

        require(deal.counterparty == msg.sender || deal.initiator == msg.sender || deal.mediator == msg.sender, "D5");
        require(deal.counterparty == _to || deal.initiator == _to || deal.mediator == _to, "D5.1");

        reviews[dealId][msg.sender][_to] = _comment;
    }
}
