# 区块链笔记管理系统 Web 界面

这是一个基于以太坊智能合约的去中心化笔记管理系统的 Web 前端界面。

## 功能特性

- 🔐 **MetaMask 钱包连接** - 安全连接你的以太坊钱包
- ✍️ **创建笔记** - 创建带标题和内容的笔记
- 📝 **编辑笔记** - 编辑已有笔记的标题和内容
- 👁️ **查看笔记** - 查看笔记的完整详情
- 🗑️ **删除笔记** - 删除不需要的笔记
- 📄 **分页列表** - 支持分页浏览笔记列表
- 📱 **响应式设计** - 支持桌面和移动设备

## 使用步骤

### 1. 安装 MetaMask

如果你还没有安装 MetaMask，请先安装浏览器扩展：
- Chrome: https://chrome.google.com/webstore/detail/metamask/
- Firefox: https://addons.mozilla.org/firefox/addon/ether-metamask/

### 2. 配置合约地址

在使用前，你需要配置智能合约地址：

1. 打开 `app.js` 文件
2. 找到 `CONTRACT_CONFIG` 对象
3. 将 `address` 字段的值替换为你部署的合约地址：

```javascript
const CONTRACT_CONFIG = {
    address: '0x你的合约地址',  // 替换这里
    abi: [...]
};
```

### 3. 部署合约

如果你还没有部署合约，请按照以下步骤：

```bash
# 在项目根目录
cd ..

# 编译合约
forge build

# 部署合约（示例，请根据实际网络调整）
forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

### 4. 启动 Web 服务器

由于使用了 ES6 模块和 CORS 限制，你需要通过 HTTP 服务器运行这个应用：

#### 方法 1: 使用 Python（推荐）

```bash
# Python 3
cd page
python3 -m http.server 8000
```

然后在浏览器中打开 http://localhost:8000

#### 方法 2: 使用 Node.js

```bash
# 安装 http-server
npm install -g http-server

# 启动服务
cd page
http-server -p 8000
```

#### 方法 3: 使用 VS Code Live Server

1. 安装 "Live Server" 扩展
2. 右键点击 `index.html`
3. 选择 "Open with Live Server"

### 5. 使用应用

1. 打开浏览器访问本地服务器地址
2. 点击"连接钱包"按钮
3. 在 MetaMask 中确认连接
4. 开始使用笔记管理功能

## 文件说明

```
page/
├── index.html      # 主页面 HTML 结构
├── app.js          # JavaScript 业务逻辑和合约交互
├── styles.css      # CSS 样式文件
└── README.md       # 使用说明（本文件）
```

## 智能合约接口

应用使用以下智能合约方法：

- `createNote(title, content)` - 创建笔记
- `updateNote(id, title, content)` - 更新笔记
- `deleteNote(id)` - 删除笔记
- `getNoteById(id)` - 获取单个笔记
- `getUserNotesWithPage(offset, limit)` - 分页获取用户笔记
- `getUserNotesCount()` - 获取用户笔记数量

## 注意事项

### Gas 费用

每次创建、更新或删除笔记都需要支付 Gas 费用：
- 创建笔记：约 100,000 - 200,000 gas
- 更新笔记：约 50,000 - 150,000 gas
- 删除笔记：约 50,000 - 100,000 gas

### 字符限制

- 标题：1-256 字符
- 内容：0-20,480 字符

### 网络要求

- 支持任何兼容 EVM 的网络
- 确保在 MetaMask 中连接到正确的网络
- 确保账户有足够的 ETH 支付 Gas 费用

## 常见问题

### 1. 无法连接钱包？

- 确保已安装 MetaMask 扩展
- 检查浏览器是否允许弹出窗口
- 刷新页面重试

### 2. 交易失败？

- 检查账户是否有足够的 ETH
- 确认合约地址配置正确
- 查看 MetaMask 中的错误信息

### 3. 看不到笔记？

- 确保连接的账户是创建笔记的账户
- 尝试点击刷新按钮
- 检查浏览器控制台是否有错误

### 4. 页面空白？

- 打开浏览器开发者工具查看控制台错误
- 确保通过 HTTP 服务器访问（不是直接打开 HTML 文件）
- 检查合约地址是否正确配置

## 技术栈

- **前端**: 原生 HTML/CSS/JavaScript
- **区块链库**: ethers.js v5
- **钱包**: MetaMask
- **智能合约**: Solidity (OpenZeppelin UUPS Upgradeable)

## 开发说明

如果你想修改或扩展功能：

1. **修改样式**: 编辑 `styles.css`
2. **修改逻辑**: 编辑 `app.js`
3. **修改界面**: 编辑 `index.html`

建议在开发时使用浏览器的开发者工具进行调试。

## 安全提示

⚠️ **重要安全提示**：

- 永远不要分享你的私钥
- 在测试网上测试后再部署到主网
- 注意 Gas 费用，避免不必要的交易
- 定期备份重要笔记数据
- 合约升级可能影响数据，请谨慎操作

## 许可证

MIT License
