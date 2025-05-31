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
    
    // Flag to track if betting is stopped
    bool public bettingStopped;

    // Flag to track if settlement has occurred
    bool public settled;

    // Flag to track if target was reached
    bool public targetReached;

    // Flag to track which side won (true = YES won, false = NO won)
    bool public yesWon;
    
    // Events
    event DonationReceived(address indexed donor, uint256 amount);
    event TargetReached(uint256 totalAmount);
    event TargetMissed(uint256 totalAmount);
    event BetPlaced(address indexed bettor, bool isYes, uint256 amount);
    event BettingStopped(uint256 remainingTarget);
    event BetsSettled(bool targetReached, uint256 totalYesBets, uint256 totalNoBets);
    event SettlementOutcome(bool targetReached, bool yesWon, uint256 finalDonationAmount);
    
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

        // Check totals after donation
        _checkTotals();
    }

    /**
     * @dev Allows users to place bets on whether the target will be reached
     * @param isYes True if betting on target being reached, false if betting on target being missed
     * @param amount Amount of tokens to bet
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

        // Check totals after bet
        _checkTotals();
    }

    /**
     * @dev Checks if total funds (donations + bets) reach the target
     * If yes, converts necessary bets to donations and stops betting
     */
    function checkTotals() external nonReentrant {
        _checkTotals();
    }

    /**
     * @dev Internal function to check totals and handle target reaching
     */
    function _checkTotals() internal {
        // If betting is already stopped, just return without reverting
        if (bettingStopped) {
            return;
        }

        require(block.number <= targetBlock, "Campaign has ended");

        // Check if target was hit (either through donations alone or including bets)
        if (totalDonated >= targetAmount || (totalDonated + totalYesBets + totalNoBets) >= targetAmount) {
            bettingStopped = true;
            emit TargetReached(targetAmount);
            emit BettingStopped(totalDonated > targetAmount ? 0 : targetAmount - totalDonated);
        }
    }

    /**
     * @dev Internal function to settle bets and handle target reaching
     * If target is hit through donations alone, bets remain unchanged
     * If target is hit including bets, necessary bets are converted to donations
     */
    function _settleBets() internal {
        require(block.number > targetBlock, "Cannot settle before target block");
        require(!settled, "Already settled");

        // Stop betting if not already stopped
        if (!bettingStopped) {
            bettingStopped = true;
        }

        // Check if target was hit through donations alone
        if (totalDonated >= targetAmount) {
            targetReached = true;
            yesWon = true; // YES bets win if target is reached
            settled = true;
            emit BetsSettled(true, totalYesBets, totalNoBets);
            emit SettlementOutcome(true, true, totalDonated);
            return;
        }

        // Check if target can be hit including bets
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
            
            targetReached = true;
            yesWon = true; // YES bets win if target is reached
            settled = true;
            emit BetsSettled(true, totalYesBets, totalNoBets);
            emit SettlementOutcome(true, true, totalDonated);
        } else {
            // Target was not hit
            targetReached = false;
            yesWon = false; // NO bets win if target is not reached
            settled = true;
            emit BetsSettled(false, totalYesBets, totalNoBets);
            emit SettlementOutcome(false, false, totalDonated);
        }
    }

    /**
     * @dev Allows the owner to withdraw funds after the target block
     */
    function withdrawFunds() external onlyOwner {
        require(block.number > targetBlock, "Cannot withdraw before target block");
        
        // Settle bets if not settled yet
        if (!settled) {
            _settleBets();
        }
        
        uint256 balance = donationToken.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        
        if (targetReached) {
            // Target reached, transfer all funds to owner
            require(
                donationToken.transfer(owner(), balance),
                "Transfer to owner failed"
            );
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

    /**
     * @dev Allows users to claim their winnings after settlement
     * @return amount The amount of tokens to be claimed
     */
    function claimWinnings() external nonReentrant returns (uint256 amount) {
        require(block.number > targetBlock, "Cannot claim before target block");
        
        // Settle bets if not settled yet
        if (!settled) {
            _settleBets();
        }

        uint256 userBet;
        uint256 totalWinningBets;
        uint256 totalWinningPool;

        if (yesWon) {
            userBet = yesBets[msg.sender];
            totalWinningBets = totalYesBets;
            totalWinningPool = totalYesBets + totalNoBets;
            yesBets[msg.sender] = 0; // Clear user's bet
        } else {
            userBet = noBets[msg.sender];
            totalWinningBets = totalNoBets;
            totalWinningPool = totalYesBets + totalNoBets;
            noBets[msg.sender] = 0; // Clear user's bet
        }

        if (userBet == 0 || totalWinningBets == 0) {
            return 0;
        }

        // Calculate winnings with better precision and overflow protection
        // First calculate the share ratio (in basis points, 10000 = 100%)
        uint256 shareRatio = (userBet * 10000) / totalWinningBets;
        
        // Then calculate the final amount using the ratio
        amount = (totalWinningPool * shareRatio) / 10000;

        if (amount > 0) {
            require(
                donationToken.transfer(msg.sender, amount),
                "Transfer failed"
            );
        }
    }

    /**
     * @dev Returns basic information about a user's position in the campaign
     * @return myDonation Amount donated by the user
     * @return myYesBet Amount bet on YES by the user
     * @return myNoBet Amount bet on NO by the user
     */
    function getMyPosition() external view returns (
        uint256 myDonation,
        uint256 myYesBet,
        uint256 myNoBet
    ) {
        myDonation = donations[msg.sender];
        myYesBet = yesBets[msg.sender];
        myNoBet = noBets[msg.sender];
    }
} 