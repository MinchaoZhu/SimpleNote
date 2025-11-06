// 合约配置示例文件
// 复制此文件为 config.js 并填入你的配置

const CONTRACT_CONFIG = {
    // 你的合约地址（部署后获得）
    address: '0x0000000000000000000000000000000000000000',
    
    // 网络配置
    networks: {
        // 本地开发网络
        localhost: {
            chainId: 31337,
            rpcUrl: 'http://localhost:8545',
            name: '本地测试网'
        },
        // Sepolia 测试网
        sepolia: {
            chainId: 11155111,
            rpcUrl: 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
            name: 'Sepolia 测试网',
            explorer: 'https://sepolia.etherscan.io'
        },
        // 以太坊主网
        mainnet: {
            chainId: 1,
            rpcUrl: 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY',
            name: '以太坊主网',
            explorer: 'https://etherscan.io'
        }
    }
};

// 导出配置（如果使用模块化）
// export default CONTRACT_CONFIG;
