# NoteManagement Smart Contract

A decentralized note management system built on Ethereum that allows users to create, update, and delete notes with custom properties. This contract features user isolation, property management, pagination, and gas-optimized operations.

## 🌟 Features

- **Complete CRUD Operations**: Create, read, update, and delete notes
- **Custom Properties**: Add up to 32 key-value properties per note
- **User Isolation**: Each user's notes are completely isolated from others
- **Pagination Support**: Efficient pagination for large note collections (1-20 notes per page)
- **Gas Optimization**: O(1) deletion algorithms and complete storage cleanup for gas refunds
- **Comprehensive Validation**: Input validation for all string parameters
- **Event Logging**: Complete event coverage for all state changes
- **Production Ready**: Extensive test coverage with 53+ test cases including fuzz testing

## 📋 Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Contract Architecture](#contract-architecture)
- [API Reference](#api-reference)
- [Gas Optimization](#gas-optimization)
- [Security](#security)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## 🚀 Installation

### Prerequisites

- Node.js >= 16.0.0
- npm or yarn
- Foundry (for testing)

### Setup

```bash
# Clone the repository
git clone https://github.com/MinchaoZhu/SimpleNote
cd SimpleNote

# Install dependencies
npm install

# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## 💻 Usage

### Basic Example

```solidity
// Deploy the contract
NoteManagement noteContract = new NoteManagement();

// Create a note
noteContract.createNote("My First Note", "This is the content of my note");

// Get note by ID
NoteManagement.NoteRecord memory note = noteContract.getNoteById(0);

// Add a property
noteContract.addProperty(0, "priority", "high");

// Get paginated notes
(NoteRecord[] memory notes, uint256 nextOffset, bool hasMore) = 
    noteContract.getUserNotesWithPage(0, 10);
```

### JavaScript Integration

```javascript
const { ethers } = require("ethers");

// Connect to contract
const noteContract = new ethers.Contract(contractAddress, abi, signer);

// Create a note
const tx = await noteContract.createNote("Hello World", "My first blockchain note");
await tx.wait();

// Listen for events
noteContract.on("NoteCreated", (id, owner, timestamp) => {
    console.log(`New note created with ID: ${id}`);
});
```

## 🏗️ Contract Architecture

### Core Components

```
NoteManagement
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
    └── Statistics
```

### Data Structures

| Component | Type | Description |
|-----------|------|-------------|
| `notes` | `NoteRecord[]` | Global array of all notes |
| `userNoteIds` | `mapping(address => uint256[])` | User's note IDs for fast lookup |
| `noteProperties` | `mapping(uint256 => mapping(string => string))` | Note properties storage |
| `notePropertyExists` | `mapping(uint256 => mapping(string => bool))` | Property existence tracking |

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

### Statistics

#### `getTotalNotesCount() returns (uint256)`
Returns total notes created (including deleted).

#### `getUserNotesCount() returns (uint256)`
Returns active notes count for calling user.

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

## 🔒 Security

### Access Control
- **Owner-only modifications**: Only note owners can modify their notes
- **User isolation**: Complete separation between user data
- **Input validation**: Comprehensive string length validation

### Security Features
- No external calls (eliminates reentrancy risk)
- SafeMath not needed (Solidity ^0.8.0 overflow protection)
- Complete event logging for auditability
- Bounds checking for all array operations

### Validated Edge Cases
- Empty content allowed (title required)
- Maximum property limits enforced
- Pagination boundary handling
- Deleted note access prevention

## 🧪 Testing

The contract includes comprehensive test coverage:

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run fuzz tests with 1000 iterations
forge test --fuzz-runs 1000
```

### Test Coverage
- **53 test cases** covering all functionality
- **Fuzz testing** with 1000+ iterations per test
- **Edge case testing** for boundary conditions
- **Security testing** for access control
- **Gas optimization validation**

### Test Categories
- ✅ CRUD Operations (12 tests)
- ✅ Property Management (15 tests)
- ✅ Pagination (8 tests)
- ✅ Input Validation (10 tests)
- ✅ Security & Access Control (8 tests)

## 🚀 Deployment

### Local Development

```bash
# Start local blockchain
anvil

# Deploy contract
forge create --rpc-url http://localhost:8545 --private-key 0x... src/NoteManagement.sol:NoteManagement
```

### Testnet Deployment

```bash
# Deploy to Sepolia
forge create --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify src/NoteManagement.sol:NoteManagement
```

### Mainnet Deployment

**Estimated Deployment Cost:** ~2.98M gas (~$10-60 depending on gas price)

```bash
# Deploy to Mainnet (use with caution)
forge create --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify src/NoteManagement.sol:NoteManagement
```

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Add tests** for new functionality
4. **Ensure** all tests pass (`forge test`)
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

### Code Standards

- **Documentation**: Complete NatSpec for all functions
- **Testing**: Minimum 95% coverage for new code
- **Gas Optimization**: Profile gas usage for new features
- **Security**: No external calls, validate all inputs

## 🔮 Future Enhancements

- [ ] IPFS integration for large content storage
- [ ] Batch operations for multiple notes
- [ ] Note sharing and collaboration features
- [ ] Advanced search and filtering
- [ ] Upgrade mechanism (UUPS proxy pattern)
- [ ] Layer 2 deployment for lower costs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/note-management-contract/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/note-management-contract/discussions)
- **Documentation**: [Full API Documentation](./docs/API.md)

## 🙏 Acknowledgments

- OpenZeppelin for security patterns and best practices
- Foundry team for excellent development tools
- Ethereum community for continuous innovation

***

**⚠️ Disclaimer:** This contract has been thoroughly tested but hasn't undergone a formal security audit. Use in production environments at your own risk.

**🏆 Status:** Production Ready - Comprehensive testing completed with 53/53 tests passing

[1](https://forum.openzeppelin.com/t/uups-proxies-tutorial-solidity-javascript/7786)
[2](https://github.com/MikeSpa/proxy-pattern)
[3](https://rareskills.io/post/uups-proxy)
[4](https://abc-71.gitbook.io/curriculum/week-7/uups-proxy-example)
[5](https://www.cyfrin.io/blog/upgradeable-proxy-smart-contract-pattern)
[6](https://coinsbench.com/a-quick-dirty-guide-to-smart-contract-upgrades-with-uups-ca1d60415038)
[7](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
[8](https://remix-ide.readthedocs.io/en/latest/run_proxy_contracts.html)