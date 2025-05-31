# GoBetMe

> Built for ETHGlobal Prague Hackathon 2025

GoBetMe is a decentralized platform that combines charitable donations with a betting system. Users can donate tokens towards a cause and place bets on whether the target amount will be reached within a specified timeframe.

## The Twist: Bet-to-Donate Mechanism

GoBetMe introduces a unique twist to traditional betting: bets are counted towards the donation target. Here's why this is both fair and economically sound:

1. **Economic Incentive Alignment**: If the target is not reached, YES bettors lose their entire bet. This creates a strong economic incentive for YES bettors to contribute additional funds to reach the target, as their potential gains exceed their loses if target is sufficiently close.

2. **Loan Arbitrage Prevention**: Without this mechanism, YES bettors could take out loans to push the target over the line, as their potential returns would exceed their loan costs. By counting bets towards the target, we eliminate this arbitrage opportunity.

3. **Fair Settlement**:
   - If the target is reached through pure donations, normal betting payouts apply
   - If the target is reached by including bets, those bets are converted to donations - potentialy partially with NO bets being forfeited first
   - If the target is not reached, NO bettors win and YES bettors lose their bets

## Smart Contracts

### GoBetMeFactory
- Deployed on Sepolia: `0x4155437A2B3576C992dDe55D7339E436645AA327`
- [View on Etherscan](https://sepolia.etherscan.io/address/0x4155437a2b3576c992dde55d7339e436645aa327)

### GoBetMe
- Campaign contract for individual donation/betting rounds
- Features:
  - Target amount tracking
  - Time-based expiration
  - Betting system with bet-to-donate mechanism
  - Automatic settlement

## How It Works

1. **Campaign Creation**:
   - Set a target amount and deadline
   - Choose the ERC20 token for donations and bets
   - Campaign starts with zero donations and bets

2. **Donation**:
   - Users can donate tokens at any time
   - Donations are tracked separately from bets
   - If target is reached through donations alone, normal betting rules apply

3. **Betting**:
   - Users can bet on YES (target will be reached) or NO (target won't be reached)
   - Bets are counted towards the target amount
   - If target is reached by including bets:
     - Necessary bets are converted to donations - NOs first, then YES
     - Betting phase is finished
     - Remaining bets are settled normally after expiry of campaign

4. **Settlement**:
   - Automatic at deadline
   - If target reached:
     - YES bettors win if reached through donations or even if inclusing the bets
     - Bets are converted to donations if needed to reach target
   - If target not reached:
     - NO bettors win
     - YES bettors lose their bets

5. **Fund Distribution**:
   - All funds go to the campaign owner if target is reached 
   - If target is not reached, funds still go to owner but marked as missed target
   - Winning bettors can withdraw their rewards 

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/gobetme.git
cd gobetme
```

2. Install dependencies:
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install frontend dependencies
cd frontend
npm install
```

3. Set up environment variables:
```bash
# Create .env file
cp .env.example .env

# Fill in your values:
SEPOLIA_RPC_URL="your-sepolia-rpc-url"
PRIVATE_KEY="your-private-key"
ETHERSCAN_API_KEY="your-etherscan-api-key"
VITE_ALCHEMY_API_KEY="your-alchemy-api-key"
VITE_GOBETME_FACTORY_ADDRESS="0x4155437A2B3576C992dDe55D7339E436645AA327"
```

4. Run local development:
```bash
# Start local blockchain
anvil

# In another terminal, run tests
forge test

# Deploy to local network
forge script script/Deploy.s.sol --broadcast

# Run frontend
cd frontend
npm run dev
```

## Testing

Run the test suite:
```bash
forge test
```

## Deployment

Deploy to Sepolia:
```bash
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Security

This project is in development. Use at your own risk. We recommend:
- Never using real funds for testing
- Auditing the contracts before use
- Using a dedicated wallet with limited funds for deployment

## Contact

For questions or support, please open an issue in the GitHub repository.
