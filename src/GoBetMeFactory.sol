// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GoBetMe.sol";

/**
 * @title GoBetMeFactory
 * @dev Factory contract for deploying GoBetMe instances
 */
contract GoBetMeFactory is Ownable {
    // Array to store all deployed GoBetMe contracts
    GoBetMe[] public campaigns;
    
    // Mapping to track campaigns by their cause name
    mapping(string => GoBetMe) public campaignsByName;
    
    // Events
    event CampaignCreated(
        address indexed campaign,
        string causeName,
        address token,
        uint256 targetAmount,
        uint256 targetBlock
    );
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Creates a new GoBetMe campaign
     * @param _donationToken Address of the ERC20 token to be donated
     * @param _causeName Name of the cause
     * @param _targetAmount Target amount to be raised
     * @param _targetBlock Block number by which target should be reached
     * @return campaign Address of the newly deployed campaign
     */
    function createCampaign(
        address _donationToken,
        string memory _causeName,
        uint256 _targetAmount,
        uint256 _targetBlock
    ) external returns (GoBetMe campaign) {
        require(bytes(_causeName).length > 0, "Cause name cannot be empty");
        require(campaignsByName[_causeName] == GoBetMe(address(0)), "Campaign name already exists");
        
        // Deploy new GoBetMe contract
        campaign = new GoBetMe(
            _donationToken,
            _causeName,
            _targetAmount,
            _targetBlock
        );
        
        // Store the campaign
        campaigns.push(campaign);
        campaignsByName[_causeName] = campaign;
        
        emit CampaignCreated(
            address(campaign),
            _causeName,
            _donationToken,
            _targetAmount,
            _targetBlock
        );
    }
    
    /**
     * @dev Returns the total number of campaigns created
     * @return count Number of campaigns
     */
    function getCampaignCount() external view returns (uint256 count) {
        return campaigns.length;
    }
    
    /**
     * @dev Returns all campaigns created
     * @return allCampaigns Array of all campaign addresses
     */
    function getAllCampaigns() external view returns (GoBetMe[] memory allCampaigns) {
        return campaigns;
    }
    
    /**
     * @dev Returns campaigns created by a specific address
     * @param creator Address of the campaign creator
     * @return creatorCampaigns Array of campaign addresses created by the specified address
     */
    function getCampaignsByCreator(address creator) external view returns (GoBetMe[] memory creatorCampaigns) {
        uint256 count = 0;
        
        // First count how many campaigns were created by this address
        for (uint256 i = 0; i < campaigns.length; i++) {
            if (campaigns[i].owner() == creator) {
                count++;
            }
        }
        
        // Then create and fill the array
        creatorCampaigns = new GoBetMe[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < campaigns.length; i++) {
            if (campaigns[i].owner() == creator) {
                creatorCampaigns[index] = campaigns[i];
                index++;
            }
        }
    }
} 