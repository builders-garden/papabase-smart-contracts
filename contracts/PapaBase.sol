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

    uint256 public campaignCount;

    address public usdcTokenAddress; //0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 usdc on Base

    address public papaBaseAdmin;

    address public acrossSpokePool; //0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64 accross spoke pool address

    modifier onlyPapaBase() {
        require(msg.sender == papaBaseAdmin, "Token is not accepted");
        _;
    }

    constructor(address admin, address _usdcTokenAddress, address _acrossSpokePool) ERC1155("") Ownable(msg.sender){
        usdcTokenAddress = _usdcTokenAddress;
        papaBaseAdmin = admin;
        acrossSpokePool = _acrossSpokePool;
    }

    /// Admin functions

    //Set the PapaBase admin address
    function setPapaBaseAdmin(address _newAdmin) onlyPapaBase public {
        papaBaseAdmin = _newAdmin;
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
        _depositFunds(_campaignId, depositAmount, msg.sender, false);
    }

    function _depositFunds(uint256 _campaignId, uint256 depositAmount, address donor, bool isCrossChainDeposit) internal {
        require(!campaigns[_campaignId].hasEnded, "Campaign has ended");
        if(!isCrossChainDeposit) {
            IERC20(usdcTokenAddress).transferFrom(donor, address(this), depositAmount);
        }
        if(campaigns[_campaignId].tokenAmount == 0) {
            // mint admin NFT for XMTP groups purposes
            _mint(papaBaseAdmin, _campaignId, 1, "");
        }
        // mint NFT
        _mint(donor, _campaignId, 1, "");
        emit DepositFunds (_campaignId, donor, depositAmount);
        campaigns[_campaignId].tokenAmount += depositAmount;
        usersDonations[donor][_campaignId] += depositAmount;
    }

    // User deposits USDC from other chains
    function handleV3AcrossMessage(
        address tokenSent, // tokenSent is unused
        uint256 amount,
        address relayer, // relayer is unused
        bytes memory message
    ) external {
        // Verify that this call came from the Across SpokePool.
        if (msg.sender != acrossSpokePool) revert UnauthorizedSender();

        if (tokenSent != usdcTokenAddress) revert UnauthorizedToken();
    
        // Decodes the user address from the message.
        (uint256 campaignId, address user) = abi.decode(message, (uint256, address));
        
        // Depisit usdc in the campaign
        _depositFunds(campaignId, amount, user, true);
    }
    
    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}