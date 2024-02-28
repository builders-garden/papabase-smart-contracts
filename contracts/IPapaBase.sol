// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPapaBase { 
    
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

    struct PapaCampaign {
        address owner;
        string name;
        string description;
        address tokenAddress;
        uint256 tokenAmount;
        bool hasEnded;
    }
}