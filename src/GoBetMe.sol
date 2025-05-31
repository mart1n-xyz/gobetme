// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title GoBetMe
 * @dev A donation contract that allows users to donate specific tokens towards a cause
 * and bet on whether the target will be reached
 */
contract GoBetMe is Ownable, ReentrancyGuard {
    // The token that can be donated and bet with
    IERC20 public immutable donationToken;
    
    // The name of the cause
    string public causeName;
    
    // The target amount to be raised
    uint256 public targetAmount;
    
    // The block number by which the target should be reached
    uint256 public targetBlock;
    
    // Total amount donated so far
    uint256 public totalDonated;
    
    // Total amount bet on YES
    uint256 public totalYesBets;
    
    // Total amount bet on NO
    uint256 public totalNoBets;
    
    // Mapping to track individual donations
    mapping(address => uint256) public donations;
    
    // Mapping to track individual YES bets
    mapping(address => uint256) public yesBets;
    
    // Mapping to track individual NO bets
    mapping(address => uint256) public noBets;
    
    // Flag to track if bets have been settled
    bool public betsSettled;
    
    // Flag to track if betting is stopped
    bool public bettingStopped;
    
    // Events
    event DonationReceived(address indexed donor, uint256 amount);
    event TargetReached(uint256 totalAmount);
    event TargetMissed(uint256 totalAmount);
    event BetPlaced(address indexed bettor, bool isYes, uint256 amount);
    event BettingStopped(uint256 remainingTarget);
    event BetsSettled(bool targetReached, uint256 totalYesBets, uint256 totalNoBets);
    
    /**
     * @dev Constructor sets up the donation campaign
     * @param _donationToken Address of the ERC20 token to be donated
     * @param _causeName Name of the cause
     * @param _targetAmount Target amount to be raised
     * @param _targetBlock Block number by which target should be reached
     */
    constructor(
        address _donationToken,
        string memory _causeName,
        uint256 _targetAmount,
        uint256 _targetBlock
    ) Ownable(msg.sender) {
        require(_donationToken != address(0), "Invalid token address");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_targetBlock > block.number, "Target block must be in the future");
        
        donationToken = IERC20(_donationToken);
        causeName = _causeName;
        targetAmount = _targetAmount;
        targetBlock = _targetBlock;
    }
    
    /**
     * @dev Allows users to donate tokens
     * @param amount Amount of tokens to donate
     */
    function donate(uint256 amount) external nonReentrant {
        require(amount > 0, "Donation amount must be greater than 0");
        require(block.number <= targetBlock, "Donation period has ended");
        
        // Transfer tokens from donor to contract
        require(
            donationToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );
        
        // Update donation tracking
        donations[msg.sender] += amount;
        totalDonated += amount;
        
        emit DonationReceived(msg.sender, amount);
        
        // Check if target has been reached
        if (totalDonated >= targetAmount) {
            emit TargetReached(totalDonated);
        }
    }

    /**
     * @dev Checks if total funds (donations + bets) reach the target
     * If yes, converts necessary bets to donations and stops betting
     */
    function checkTotals() external nonReentrant {
        require(!bettingStopped, "Betting is already stopped");
        require(block.number <= targetBlock, "Campaign has ended");

        // First check if target was already hit through donations
        if (totalDonated >= targetAmount) {
            bettingStopped = true;
            emit BettingStopped(0); // No remaining target as it's already hit
            _settleBets();
            return;
        }

        uint256 totalFunds = totalDonated + totalYesBets + totalNoBets;
        
        if (totalFunds >= targetAmount) {
            uint256 remainingTarget = targetAmount - totalDonated;
            
            // First try to take from NO bets
            if (totalNoBets >= remainingTarget) {
                // Take all needed from NO bets
                totalNoBets -= remainingTarget;
                totalDonated += remainingTarget;
            } else {
                // Take all NO bets and remainder from YES bets
                uint256 fromNoBets = totalNoBets;
                uint256 fromYesBets = remainingTarget - fromNoBets;
                
                totalDonated += fromNoBets + fromYesBets;
                totalNoBets = 0;
                totalYesBets -= fromYesBets;
            }
            
            // Stop betting
            bettingStopped = true;
            emit BettingStopped(remainingTarget);
            
            // Call settlement (placeholder for now)
            _settleBets();
        }
    }

    /**
     * @dev Placeholder for bet settlement logic
     * To be implemented with more nuanced settlement rules
     */
    function _settleBets() internal {
        // TODO: Implement settlement logic
        emit BetsSettled(true, totalYesBets, totalNoBets);
    }

    /**
     * @dev Modified placeBet to check if betting is stopped
     */
    function placeBet(bool isYes, uint256 amount) external nonReentrant {
        require(amount > 0, "Bet amount must be greater than 0");
        require(block.number <= targetBlock, "Betting period has ended");
        require(!bettingStopped, "Betting is stopped");
        
        // Transfer tokens from bettor to contract
        require(
            donationToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );
        
        // Update bet tracking
        if (isYes) {
            yesBets[msg.sender] += amount;
            totalYesBets += amount;
        } else {
            noBets[msg.sender] += amount;
            totalNoBets += amount;
        }
        
        emit BetPlaced(msg.sender, isYes, amount);
    }
    
    
    /**
     * @dev Allows the owner to withdraw funds and settle bets after the target block
     */
    function withdrawFunds() external onlyOwner {
        require(block.number > targetBlock, "Cannot withdraw before target block");
        require(!betsSettled, "Bets already settled");
        
        uint256 balance = donationToken.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        
        bool targetReached = totalDonated >= targetAmount;
        
        if (targetReached) {
            // Target reached, transfer all funds to owner
            require(
                donationToken.transfer(owner(), balance),
                "Transfer to owner failed"
            );
            emit TargetReached(totalDonated);
        } else {
            // Target missed, emit event
            emit TargetMissed(totalDonated);
            // Still allow withdrawal of collected funds
            require(
                donationToken.transfer(owner(), balance),
                "Transfer to owner failed"
            );
        }

    }
    
    /**
     * @dev Returns the current status of the donation campaign
     * @return progress Percentage of target reached (in basis points, 10000 = 100%)
     * @return timeLeft Number of blocks remaining
     * @return isTargetReached Whether the target has been reached
     */
    function getStatus() external view returns (
        uint256 progress,
        uint256 timeLeft,
        bool isTargetReached
    ) {
        progress = (totalDonated * 10000) / targetAmount;
        timeLeft = block.number >= targetBlock ? 0 : targetBlock - block.number;
        isTargetReached = totalDonated >= targetAmount;
    }
} 