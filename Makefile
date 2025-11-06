# NoteManagement Contract Makefile
# Provides convenient commands for development and testing

.PHONY: help install build test test-unit test-integration test-all clean deploy upgrade

# Default target
help:
	@echo "NoteManagement Contract - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  install     Install dependencies"
	@echo "  build       Build the project"
	@echo "  clean       Clean build artifacts"
	@echo ""
	@echo "Testing:"
	@echo "  test        Run all tests (unit + integration)"
	@echo "  test-unit   Run unit tests only"
	@echo "  test-integration  Run integration tests (deployment script)"
	@echo "  test-uups   Run UUPS upgrade tests only"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy      Deploy contract to local network"
	@echo "  upgrade     Run upgrade example"
	@echo ""
	@echo "Utilities:"
	@echo "  anvil       Start local blockchain"
	@echo "  stop-anvil  Stop local blockchain"

# Install dependencies
install:
	@echo "Installing dependencies..."
	forge install OpenZeppelin/openzeppelin-contracts
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable

# Build the project
build:
	@echo "Building project..."
	forge build

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -f anvil.log
	rm -f test/anvil.log
	rm -rf broadcast
	rm -rf cache
	rm -rf out

# Run all tests
test: test-unit test-integration

# Run unit tests only
test-unit:
	@echo "Running unit tests..."
	forge test -vv --gas-report

# Run integration tests (deployment script)
test-integration:
	@echo "Running integration tests..."
	cd test && bash TestNoteManagement.t.sh

# Deploy contract to local network
deploy:
	@echo "Deploying contract..."
	forge script script/DeployUUPS.s.sol:DeployUUPS --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --rpc-url http://localhost:18545

# Run upgrade example
upgrade:
	@echo "Running upgrade example..."
	forge script script/UpgradeExample.s.sol:UpgradeExample --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --rpc-url http://localhost:18545

# Start local blockchain
anvil:
	@echo "Starting local blockchain..."
	anvil --port 18545 --host 0.0.0.0

# Stop local blockchain
stop-anvil:
	@echo "Stopping local blockchain..."
	pkill -f anvil || true

# Development workflow
dev: clean build test
	@echo "Development workflow completed!"

# CI/CD workflow
ci: install clean build test
	@echo "CI/CD workflow completed!"