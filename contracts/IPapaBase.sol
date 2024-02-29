// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPapaBase { 

    error UnauthorizedSender();
    error UnauthorizedToken();
    
    event CampaignCreated(
            uint256 campaignId,
            address owner,
            string name,
            string description
    );

    event CampaignHasEnded(uint256 campaignId);

    event WithdrawFunds(uint256 campaignId, uint256 withdrawAmount);

    event DepositFunds(uint256 campaignId, address user, uint256 depositAmount);

    event PendingDeposit(uint256 campaignId, address user, uint256 depositAmount);

    event RecurringDespositCreated(
        uint256 campaignId,
        address user,
        uint256 totalDepositAmount,
        uint256 recurringDepositAmount,
        uint256 depositFrequency
    );

    struct PapaCampaign {
        address owner;
        string name;
        string description;
        address tokenAddress;
        uint256 tokenAmount;
        bool hasEnded;
    }

    struct PapaRecurringDeposit {
        address user;
        uint256 campaignId;
        uint256 totalDepositAmount;
        uint256 donationAmountLeft;
        uint256 recurringDepositAmount;
        uint256 depositFrequency;
        uint256 lastDepositTime;
        uint256 nextDepositTime;
        bool hasEnded;
    }
}