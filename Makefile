-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
SEPOLIA_PUBLIC_KEY := 0xc55FAfFc48A8E35eDB53EEA3d91Ec2dCc7fD3100

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Default arguments for localhost
ANVIL_ARGS := --rpc-url http://localhost:8545 --sender $(DEFAULT_ANVIL_KEY) --account testKey --broadcast -vvvv

SEPOLIA_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --sender $(SEPOLIA_PUBLIC_KEY) --account account1Key --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv


# Default deploy target (localhost)
deploy:
	@forge script script/DeployLottery.s.sol:DeployLottery $(ANVIL_ARGS)

# Sepolia deploy target
deploy-sepolia:
	@forge script script/DeployLottery.s.sol:DeployLottery $(SEPOLIA_ARGS)




createSubscription:
	@forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)
	
createSubscription-sepolia:
	@forge script script/Interactions.s.sol:CreateSubscription $(SEPOLIA_ARGS)

addConsumer:
	@forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

addConsumer-sepolia:
	@forge script script/Interactions.s.sol:AddConsumer $(SEPOLIA_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

fundSubscription:
	@forge script script/Interactions.s.sol:FundSubscription $(SEPOLIA_ARGS)

