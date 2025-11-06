# NoteManagement Smart Contract

A decentralized, upgradeable note management system built on Ethereum using the UUPS (Universal Upgradeable Proxy Standard) pattern. This contract allows users to create, update, and delete notes with custom properties, featuring user isolation, property management, pagination, and gas-optimized operations.

## 🌟 Features

- **Complete CRUD Operations**: Create, read, update, and delete notes
- **Custom Properties**: Add up to 32 key-value properties per note
- **User Isolation**: Each user's notes are completely isolated from others
- **Pagination Support**: Efficient pagination for large note collections (1-20 notes per page)
- **UUPS Upgradeable**: Seamless contract upgrades without data loss
- **Version Management**: Built-in version tracking for upgrade compatibility
- **Gas Optimization**: O(1) deletion algorithms and complete storage cleanup for gas refunds
- **Comprehensive Validation**: Input validation for all string parameters
- **Event Logging**: Complete event coverage for all state changes
- **Production Ready**: Extensive test coverage with 66+ test cases including fuzz testing

## 📋 Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Contract Architecture](#contract-architecture)
- [UUPS Upgrade System](#uups-upgrade-system)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## 🚀 Installation

### Prerequisites

- Node.js >= 16.0.0
- Foundry (for testing and deployment)
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/MinchaoZhu/SimpleNote
cd SimpleNote

# Install dependencies using Makefile
make install

# Build the project
make build
```

## 💻 Usage

### Basic Example

```solidity
// Deploy the UUPS proxy
NoteManagement proxy = NoteManagement(proxyAddress);

// Create a note
proxy.createNote("My First Note", "This is the content of my note");

// Get note by ID
NoteManagement.NoteRecord memory note = proxy.getNoteById(0);

// Add a property
proxy.addProperty(0, "priority", "high");

// Get paginated notes
(NoteRecord[] memory notes, uint256 nextOffset, bool hasMore) = 
    proxy.getUserNotesWithPage(0, 10);
```

### JavaScript Integration

```javascript
const { ethers } = require("ethers");

// Connect to proxy contract
const proxyContract = new ethers.Contract(proxyAddress, abi, signer);

// Create a note
const tx = await proxyContract.createNote("Hello World", "My first blockchain note");
await tx.wait();

// Listen for events
proxyContract.on("NoteCreated", (id, owner, timestamp) => {
    console.log(`New note created with ID: ${id}`);
});
```

## 🏗️ Contract Architecture

### Core Components

```
NoteManagement (V1)
├── UUPS Upgradeable
│   ├── Initializable
│   ├── UUPSUpgradeable
│   └── OwnableUpgradeable
├── NoteRecord Struct
│   ├── id: Unique identifier
│   ├── timestamp: Last modification time
│   ├── owner: Note owner address
│   ├── isValid: Deletion status
│   ├── title: Note title (1-256 chars)
│   ├── content: Note content (0-20480 chars)
│   └── propertyKeys: Array of property keys
├── Storage Mappings
│   ├── userNoteIds: User → Note IDs mapping
│   ├── noteProperties: Note → Properties mapping
│   ├── notePropertyExists: Existence tracking
│   └── notePropertiesKeyIndices: O(1) deletion indices
└── Functions
    ├── CRUD Operations
    ├── Property Management
    ├── Pagination
    ├── Version Management
    └── Statistics
```

### Data Structures

| Component | Type | Description |
|-----------|------|-------------|
| `notes` | `NoteRecord[]` | Global array of all notes |
| `userNoteIds` | `mapping(address => uint256[])` | User's note IDs for fast lookup |
| `noteProperties` | `mapping(uint256 => mapping(string => string))` | Note properties storage |
| `notePropertyExists` | `mapping(uint256 => mapping(string => bool))` | Property existence tracking |
| `VERSION` | `uint256` | Contract version for upgrade tracking |

## 🔄 UUPS Upgrade System

This contract implements the UUPS (Universal Upgradeable Proxy Standard) pattern, allowing for seamless upgrades while preserving all user data.

### Key Features

- **Data Preservation**: All notes and properties are preserved during upgrades
- **Version Tracking**: Built-in version management for upgrade compatibility
- **Owner-Only Upgrades**: Only the contract owner can perform upgrades
- **Storage Layout Safety**: Upgrades maintain storage layout compatibility

### Upgrade Process

1. **Deploy New Implementation**: Deploy the new contract version
2. **Authorize Upgrade**: Owner calls `upgradeToAndCall()` on the proxy
3. **Data Migration**: All existing data is automatically preserved
4. **Version Update**: Contract version is updated to reflect the new implementation

### Example Upgrade

```solidity
// Deploy V2 implementation
NoteManagementV2 v2Implementation = new NoteManagementV2();

// Upgrade the proxy to V2
proxy.upgradeToAndCall(address(v2Implementation), "");

// Verify version update
uint256 newVersion = proxy.getVersion(); // Returns 2
```

### V2 Features (Example)

The contract includes a V2 implementation with additional features:

- **Note Tags**: Add multiple tags to notes
- **Priority Levels**: Set priority (Low, Medium, High, Critical)
- **Priority Filtering**: Filter notes by priority level
- **Enhanced Events**: Additional events for new features

## 📚 API Reference

### Core Functions

#### `createNote(string memory _title, string memory _content)`
Creates a new note with the specified title and content.

**Parameters:**
- `_title`: Note title (1-256 characters)
- `_content`: Note content (0-20480 characters)

**Events:** `NoteCreated(uint256 indexed id, address indexed owner, uint256 timestamp)`

#### `getNoteById(uint256 _id) returns (NoteRecord memory)`
Retrieves a note by its global ID.

#### `getUserNotesWithPage(uint256 offset, uint256 limit)`
Retrieves paginated notes for the calling user.

**Returns:**
- `userNotes`: Array of note records
- `nextOffset`: Starting index for next page
- `hasMore`: Boolean indicating more notes available

### Property Management

#### `addProperty(uint256 _id, string memory _key, string memory _value)`
Adds or updates a property for a note.

**Constraints:**
- Key: 1-32 characters
- Value: 1-2048 characters
- Maximum 32 properties per note

#### `deleteProperty(uint256 _id, string memory _key)`
Deletes a property using O(1) array deletion algorithm.

### Version Management

#### `getVersion() returns (uint256)`
Returns the current contract version.

### Statistics

#### `getTotalNotesCount() returns (uint256)`
Returns total notes created (including deleted).

#### `getUserNotesCount() returns (uint256)`
Returns active notes count for calling user.

## 🧪 Testing

The contract includes comprehensive test coverage with multiple testing approaches:

### Quick Start

```bash
# Run all tests (recommended)
make test

# Run specific test types
make test-unit          # Unit tests only
make test-integration   # Integration tests only
```

### Test Types

#### 1. Unit Tests (Solidity)
```bash
# Run all unit tests
forge test

# Run with gas reporting
forge test --gas-report

# Run fuzz tests with 1000 iterations
forge test --fuzz-runs 1000

# Run UUPS upgrade tests
forge test --match-contract NoteManagementUUPSTest -vv
```

#### 2. Integration Tests (Deployment)
```bash
# Run deployment and integration tests
make test-integration

# Run specific test modes
cd test && bash TestNoteManagement.t.sh basic    # Basic functionality
cd test && bash TestNoteManagement.t.sh uups     # UUPS proxy tests
cd test && bash TestNoteManagement.t.sh upgrade  # Upgrade tests
```

### Test Coverage

- **66+ test cases** covering all functionality
- **Unit tests**: 53 Solidity test cases
- **UUPS tests**: 13 upgrade functionality tests
- **Integration tests**: 57+ deployment and interaction tests
- **Fuzz testing** with 256+ iterations per test
- **Edge case testing** for boundary conditions
- **Security testing** for access control
- **Upgrade testing** for data preservation

### Test Categories

- ✅ CRUD Operations (12 tests)
- ✅ Property Management (15 tests)
- ✅ Pagination (8 tests)
- ✅ Input Validation (10 tests)
- ✅ Security & Access Control (8 tests)
- ✅ UUPS Upgrade Functionality (13 tests)
- ✅ Integration & Deployment (57+ tests)

### Test Structure

```
test/
├── NoteManagement.t.sol          # Unit tests
├── NoteManagementUUPS.t.sol      # UUPS upgrade tests
├── TestNoteManagement.t.sh       # Integration tests
└── base.t.sol                    # V2 implementation for testing
```

## 🚀 Deployment

### Local Development

```bash
# Start local blockchain
make anvil

# Deploy UUPS proxy
make deploy

# Run upgrade example
make upgrade
```

### UUPS Deployment

```bash
# Deploy using the UUPS script
forge script script/DeployUUPS.s.sol:DeployUUPS --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Testnet Deployment

```bash
# Deploy to Sepolia
forge script script/DeployUUPS.s.sol:DeployUUPS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Mainnet Deployment

**Estimated Deployment Cost:** ~3.5M gas (~$15-80 depending on gas price)

```bash
# Deploy to Mainnet (use with caution)
forge script script/DeployUUPS.s.sol:DeployUUPS --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

## ⚡ Gas Optimization

This contract implements several gas optimization techniques:

### O(1) Array Deletion
```solidity
// Swap-and-pop algorithm for efficient deletion
if (keyIndex != keys.length - 1) {
    string memory lastKey = keys[keys.length - 1];
    keys[keyIndex] = lastKey;
    notePropertiesKeyIndices[_id][lastKey] = keyIndex;
}
keys.pop();
```

### Storage Cleanup
- Complete mapping cleanup in `deleteNote()` for gas refunds
- Struct packing optimization (`address` + `bool` in same slot)
- Strategic use of `delete` keyword for gas refunds

### Performance Metrics

| Operation | Average Gas | Optimized Feature |
|-----------|-------------|-------------------|
| Create Note | 201k gas | Struct packing |
| Delete Note | 56k gas | Complete cleanup |
| Add Property | 151k gas | Existence mapping |
| Delete Property | 55k gas | O(1) deletion |
| Pagination | 49k gas | Efficient iteration |
| Upgrade | 180k gas | UUPS optimization |

## 🔒 Security

### Access Control
- **Owner-only upgrades**: Only contract owner can perform upgrades
- **Owner-only modifications**: Only note owners can modify their notes
- **User isolation**: Complete separation between user data
- **Input validation**: Comprehensive string length validation

### Security Features
- No external calls (eliminates reentrancy risk)
- SafeMath not needed (Solidity ^0.8.0 overflow protection)
- Complete event logging for auditability
- Bounds checking for all array operations
- UUPS upgrade authorization checks

### Validated Edge Cases
- Empty content allowed (title required)
- Maximum property limits enforced
- Pagination boundary handling
- Deleted note access prevention
- Upgrade data preservation

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Add tests** for new functionality
4. **Ensure** all tests pass (`make test`)
5. **Update** documentation as needed
6. **Commit** changes (`git commit -m 'Add amazing feature'`)
7. **Push** to branch (`git push origin feature/amazing-feature`)
8. **Open** a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Add NatSpec documentation for new functions
- Include comprehensive tests
- Optimize for gas efficiency
- Ensure security best practices
- Maintain storage layout compatibility for upgrades

### Code Standards

- **Documentation**: Complete NatSpec for all functions
- **Testing**: Minimum 95% coverage for new code
- **Gas Optimization**: Profile gas usage for new features
- **Security**: No external calls, validate all inputs
- **Upgrade Safety**: Maintain storage layout compatibility

## 🔮 Future Enhancements

- [ ] IPFS integration for large content storage
- [ ] Batch operations for multiple notes
- [ ] Note sharing and collaboration features
- [ ] Advanced search and filtering
- [ ] Layer 2 deployment for lower costs
- [ ] Multi-signature upgrade authorization
- [ ] Timelock for upgrade delays

## 📄 License

This project is licensed under the MIT License - see the [LICENSE-MIT](LICENSE-MIT) file for details.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/MinchaoZhu/SimpleNote/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MinchaoZhu/SimpleNote/discussions)

## 🙏 Acknowledgments

- OpenZeppelin for UUPS patterns and security best practices
- Foundry team for excellent development tools
- Ethereum community for continuous innovation

***

**⚠️ Disclaimer:** This contract has been thoroughly tested but hasn't undergone a formal security audit. Use in production environments at your own risk.

**🏆 Status:** Production Ready - Comprehensive testing completed with 66/66 tests passing

**🔄 Upgrade Ready:** UUPS pattern implemented for seamless contract upgrades