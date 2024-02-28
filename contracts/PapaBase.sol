// SPDX-License-Identifier: MIT 
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPapaBase.sol";

pragma solidity ^0.8.24;

contract PapaBase is IPapaBase, ERC1155, Ownable, ERC1155Supply {

    mapping(uint256 => PapaCampaign) public campaigns;

    mapping(address => mapping(uint256 => uint256)) public usersDonations;

    mapping(uint256 => mapping(address => uint256)) public pendingSwaps;

    mapping (uint256 => address) public pendingSwapTokens;

    mapping(address => bool) public isTokenAccepted;

    uint256 public campaignCount;

    address public usdcTokenAddress;

    address public papaBaseAdmin;

    address public exchangeProxy; //0xdef1c0ded9bec7f1a1670819833240f027b25eff on Base

    address public relayer;

    modifier onlyPapaBase() {
        require(msg.sender == papaBaseAdmin, "Token is not accepted");
        _;
    }

    modifier onlyPapaBaseOrTrustedRelayer() {
        require(msg.sender == papaBaseAdmin || msg.sender == relayer, "Token is not accepted");
        _;
    }

    constructor(address _usdcTokenAddress, address[] memory _acceptedTokens, address _exchangeProxy, address _relayer) ERC1155("") Ownable(msg.sender){
        usdcTokenAddress = _usdcTokenAddress;
        papaBaseAdmin = msg.sender;
        exchangeProxy = _exchangeProxy;
        relayer = _relayer;
        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            isTokenAccepted[_acceptedTokens[i]] = true;
        }
    }

    /// Admin functions

    //Set the PapaBase admin address
    function setPapaBaseAdmin(address _newAdmin) onlyPapaBase public {
        papaBaseAdmin = _newAdmin;
    }

    //Add new accepted token
    function addAcceptedToken(address[] memory _tokenAddress) onlyPapaBase public {
        for (uint256 i = 0; i < _tokenAddress.length; i++) {
            isTokenAccepted[_tokenAddress[i]] = true;
        }
    }

    // Remove accepted token
    function removeAcceptedToken(address[] memory _tokenAddress) onlyPapaBase public {
        for (uint256 i = 0; i < _tokenAddress.length; i++) {
            isTokenAccepted[_tokenAddress[i]] = false;
        }
    }

    /// Get functions

    // Get campaign by id
    function getCampaign(uint256 _campaignId) public view returns (PapaCampaign memory) {
        return campaigns[_campaignId];
    }

    // Get user campaigns
    function getUserCampaigns(address _user) public view returns (PapaCampaign[] memory) {
        PapaCampaign[] memory userCampaigns = new PapaCampaign[](campaignCount);
        uint256 userCampaignsCount = 0;
        for (uint256 i = 1; i <= campaignCount; i++) {
            if (campaigns[i].owner == _user) {
                userCampaigns[userCampaignsCount] = campaigns[i];
                userCampaignsCount++;
            }
        }
        return userCampaigns;
    }

    /// Campaign functions

    // Create a new campaign
    function createCampaign(
        string memory _name,
        string memory _description
    ) public {
        // increment campaign count
        unchecked {
            campaignCount++;
        }
        // create new campaign
        campaigns[campaignCount] = PapaCampaign(
            msg.sender,
            _name,
            _description,
            usdcTokenAddress,
            0,
            false
        );
        emit CampaignCreated(campaignCount, msg.sender, _name, _description);
    }

    // End a campaign
    function endCampaign(uint256 _campaignId) public {
        require(campaigns[_campaignId].owner == msg.sender, "You are not the owner of this campaign");
        campaigns[_campaignId].hasEnded = true;
        emit CampaignHasEnded(_campaignId);
    }
    
    // Campaign owner withdraw funds from a campaign
    function campaignWithdrawFunds(uint256 _campaignId, uint256 withdrawAmount) public {
        require(campaigns[_campaignId].owner == msg.sender, "You are not the owner of this campaign");
        require(campaigns[_campaignId].tokenAmount >= withdrawAmount, "Insufficient funds");
        IERC20(usdcTokenAddress).transfer(msg.sender, withdrawAmount);
        campaigns[_campaignId].tokenAmount -= withdrawAmount;
        emit WithdrawFunds(_campaignId, withdrawAmount);
    }

    // User deposit funds to a campaign. Directly deposit USDC
    function depositFunds(uint256 _campaignId, uint256 depositAmount) public {
        require(!campaigns[_campaignId].hasEnded, "Campaign has ended");
        IERC20(usdcTokenAddress).transferFrom(msg.sender, address(this), depositAmount);
        campaigns[_campaignId].tokenAmount += depositAmount;
        usersDonations[msg.sender][_campaignId] += depositAmount;
        // mint NFT
        _mint(msg.sender, _campaignId, 1, "");
        emit DepositFunds (_campaignId, msg.sender, depositAmount);
    }

    // User deposit funds to a campaign. Deposit accepted ERC20 token
    function swapAndDepositFunds(uint256 _campaignId, uint256 depositAmount, address tokenToDeposit) public {
        require(!campaigns[_campaignId].hasEnded, "Campaign has ended");
        require(isTokenAccepted[tokenToDeposit], "Token is not accepted");
        IERC20(tokenToDeposit).transferFrom(msg.sender, address(this), depositAmount);
        // get the pendingSwapId hashing the campaignId, tokenToDeposit, the msg.sender and block.timestamp
        uint256 pendingSwapId = uint256(keccak256(abi.encodePacked(_campaignId, tokenToDeposit, msg.sender, depositAmount, block.timestamp)));
        pendingSwaps[pendingSwapId][msg.sender] += depositAmount;
        pendingSwapTokens[pendingSwapId] = tokenToDeposit;
        emit PendingDeposit(_campaignId, msg.sender, depositAmount);
    }

    // PapaBase admin (or relayer) calls this function to complete the swap and deposit funds to a campaign
    function swapAndDepositFundsComplete(uint256 _campaignId, uint256 pendingSwapId, address donor, address spender, bytes calldata swapCallData) onlyPapaBaseOrTrustedRelayer public{
        require(!campaigns[_campaignId].hasEnded, "Campaign has ended");

        address tokenToSell = pendingSwapTokens[pendingSwapId];

        uint256 boughtAmount = fillQuote(tokenToSell, spender, donor, payable(exchangeProxy), swapCallData);

        campaigns[_campaignId].tokenAmount += boughtAmount;
        usersDonations[donor][_campaignId] += boughtAmount;

        // update pendingSwaps
        pendingSwaps[pendingSwapId][donor] = 0;
        pendingSwapTokens[pendingSwapId] = address(0);

        emit DepositFunds (_campaignId, donor, boughtAmount);
    }

    // Swaps ERC20->ERC20 tokens held by this contract using a 0x-API quote on behalf of the user
    function fillQuote(
        address sellToken,
        // The `allowanceTarget` field from the API response
        address spender,
        // The dono address
        address donor,
        // The `to` field from the API response
        address payable swapTarget,
        // The `data` field from the API response
        bytes calldata swapCallData
    )
        internal
        returns (uint256 swappedAmount)
    {
        // Checks that the swapTarget is actually the address of 0x ExchangeProxy
        require(swapTarget == exchangeProxy, "Target not ExchangeProxy");

        // Track our balance of usdc to determine how much we've bought
        uint256 usdcBoughtAmount = IERC20(usdcTokenAddress).balanceOf(address(this));

        // Give the 0x ExchangeProxy allowance to spend the sellToken
        require(IERC20(sellToken).approve(spender, type(uint256).max), 'FAILED_ERC20_APPROVAL');
        // Call the encoded swap function call on the contract at `swapTarget`
        (bool success,) = swapTarget.call{value: 0}(swapCallData);
        require(success, 'SWAP_CALL_FAILED');

        uint256 sellTokenBalancePost = IERC20(sellToken).balanceOf(address(this));
        // Refund any refund from swap to the sender
        if (sellTokenBalancePost > 0) {
            IERC20(sellToken).transfer(donor, sellTokenBalancePost);
        }
        // Use our current buyToken balance to determine how much we've bought
        return(swappedAmount = IERC20(usdcTokenAddress).balanceOf(address(this)) - usdcBoughtAmount);
    }

    // User can withdraw pending funds from a campaign if the swap is not completed yet
    function withdrawPendingSwap(uint256 pendingSwapId) public {
        require(pendingSwaps[pendingSwapId][msg.sender] > 0, "No pending swap");
        require(pendingSwapTokens[pendingSwapId] != address(0), "No pending swap");
        IERC20(pendingSwapTokens[pendingSwapId]).transfer(msg.sender, pendingSwaps[pendingSwapId][msg.sender]);
        pendingSwaps[pendingSwapId][msg.sender] = 0;
        pendingSwapTokens[pendingSwapId] = address(0);
    }

    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}