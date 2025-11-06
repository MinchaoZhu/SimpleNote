// 合约配置
const CONTRACT_CONFIG = {
    // 请在这里填入你部署的合约地址
    address: 'YOUR_CONTRACT_ADDRESS_HERE',
    // 合约 ABI
    abi: [
        "function createNote(string memory _title, string memory _content)",
        "function getNoteById(uint256 _id) view returns (tuple(uint256 id, uint256 timestamp, address owner, bool isValid, string title, string content, string[] propertyKeys))",
        "function getUserNotesWithPage(uint256 offset, uint256 limit) view returns (tuple(uint256 id, uint256 timestamp, address owner, bool isValid, string title, string content, string[] propertyKeys)[] userNotes, uint256 nextOffset, bool hasMore)",
        "function updateNote(uint256 _id, string memory _title, string memory _newContent)",
        "function deleteNote(uint256 _id)",
        "function getUserNotesCount() view returns (uint256)",
        "event NoteCreated(uint256 indexed id, address indexed owner, uint256 timestamp)",
        "event NoteUpdated(uint256 indexed id, uint256 timestamp)",
        "event NoteDeleted(uint256 indexed id)"
    ]
};

// 全局变量
let provider;
let signer;
let contract;
let userAddress;
let currentPage = 0;
const PAGE_SIZE = 10;
let currentViewNoteId = null;
let currentEditNoteId = null;

// 初始化
window.addEventListener('DOMContentLoaded', async () => {
    // 检查是否已安装 MetaMask
    if (typeof window.ethereum === 'undefined') {
        showToast('请先安装 MetaMask 钱包', 'error');
        return;
    }

    // 监听账户变化
    window.ethereum.on('accountsChanged', handleAccountsChanged);
    
    // 监听网络变化
    window.ethereum.on('chainChanged', () => {
        window.location.reload();
    });

    // 绑定事件
    document.getElementById('connectWallet').addEventListener('click', connectWallet);
    document.getElementById('createNoteBtn').addEventListener('click', openCreateNoteModal);
    document.getElementById('refreshBtn').addEventListener('click', loadNotes);
    document.getElementById('noteForm').addEventListener('submit', handleSaveNote);
    document.getElementById('prevPage').addEventListener('click', () => changePage(-1));
    document.getElementById('nextPage').addEventListener('click', () => changePage(1));
    
    // 内容字符计数
    document.getElementById('noteContent').addEventListener('input', (e) => {
        document.getElementById('contentLength').textContent = e.target.value.length;
    });

    // 尝试自动连接
    await tryAutoConnect();
});

// 尝试自动连接钱包
async function tryAutoConnect() {
    try {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
            await initializeApp();
        }
    } catch (error) {
        console.error('Auto connect error:', error);
    }
}

// 连接钱包
async function connectWallet() {
    try {
        if (typeof window.ethereum === 'undefined') {
            showToast('请先安装 MetaMask 钱包', 'error');
            return;
        }

        showLoading(true);
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        
        if (accounts.length > 0) {
            await initializeApp();
            showToast('钱包连接成功！', 'success');
        }
    } catch (error) {
        console.error('Connect wallet error:', error);
        if (error.code === 4001) {
            showToast('用户拒绝连接', 'error');
        } else {
            showToast('连接钱包失败: ' + error.message, 'error');
        }
    } finally {
        showLoading(false);
    }
}

// 初始化应用
async function initializeApp() {
    try {
        provider = new ethers.providers.Web3Provider(window.ethereum);
        signer = provider.getSigner();
        userAddress = await signer.getAddress();
        
        // 检查合约地址是否配置
        if (CONTRACT_CONFIG.address === 'YOUR_CONTRACT_ADDRESS_HERE') {
            showToast('请先在 app.js 中配置合约地址', 'error');
            document.getElementById('connectPrompt').classList.remove('hidden');
            document.getElementById('notesApp').classList.add('hidden');
            return;
        }
        
        contract = new ethers.Contract(CONTRACT_CONFIG.address, CONTRACT_CONFIG.abi, signer);

        // 更新 UI
        updateWalletUI();
        document.getElementById('connectPrompt').classList.add('hidden');
        document.getElementById('notesApp').classList.remove('hidden');

        // 加载笔记
        await loadNotes();
    } catch (error) {
        console.error('Initialize error:', error);
        showToast('初始化失败: ' + error.message, 'error');
    }
}

// 更新钱包 UI
async function updateWalletUI() {
    const shortAddress = userAddress.slice(0, 6) + '...' + userAddress.slice(-4);
    document.getElementById('walletAddress').textContent = shortAddress;
    
    try {
        const count = await contract.getUserNotesCount();
        document.getElementById('noteCount').textContent = `笔记: ${count.toString()}`;
    } catch (error) {
        console.error('Get note count error:', error);
    }
    
    document.getElementById('connectWallet').classList.add('hidden');
    document.getElementById('walletInfo').classList.remove('hidden');
}

// 处理账户变化
function handleAccountsChanged(accounts) {
    if (accounts.length === 0) {
        // 用户断开了连接
        location.reload();
    } else {
        // 用户切换了账户
        location.reload();
    }
}

// 加载笔记列表
async function loadNotes() {
    try {
        showLoading(true);
        
        const offset = currentPage * PAGE_SIZE;
        const result = await contract.getUserNotesWithPage(offset, PAGE_SIZE);
        
        const notes = result.userNotes;
        const hasMore = result.hasMore;

        displayNotes(notes);
        updatePagination(notes.length, hasMore);
        
        // 更新笔记计数
        const count = await contract.getUserNotesCount();
        document.getElementById('noteCount').textContent = `笔记: ${count.toString()}`;
    } catch (error) {
        console.error('Load notes error:', error);
        showToast('加载笔记失败: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

// 显示笔记列表
function displayNotes(notes) {
    const notesList = document.getElementById('notesList');
    const emptyState = document.getElementById('emptyState');
    
    notesList.innerHTML = '';
    
    if (notes.length === 0 && currentPage === 0) {
        emptyState.classList.remove('hidden');
        notesList.classList.add('hidden');
    } else {
        emptyState.classList.add('hidden');
        notesList.classList.remove('hidden');
        
        notes.forEach(note => {
            const noteCard = createNoteCard(note);
            notesList.appendChild(noteCard);
        });
    }
}

// 创建笔记卡片
function createNoteCard(note) {
    const card = document.createElement('div');
    card.className = 'note-card';
    
    const timestamp = new Date(note.timestamp.toNumber() * 1000);
    const formattedTime = formatDate(timestamp);
    
    // 截取内容预览
    const preview = note.content.length > 150 
        ? note.content.substring(0, 150) + '...' 
        : note.content;
    
    card.innerHTML = `
        <div class="note-card-header">
            <h3 class="note-title">${escapeHtml(note.title)}</h3>
            <span class="note-id">#${note.id.toString()}</span>
        </div>
        <div class="note-preview">${escapeHtml(preview)}</div>
        <div class="note-card-footer">
            <span class="note-time">🕒 ${formattedTime}</span>
            <div class="note-actions">
                <button class="btn-icon" onclick="viewNote(${note.id})" title="查看">
                    👁️
                </button>
                <button class="btn-icon" onclick="openEditNoteModal(${note.id})" title="编辑">
                    ✏️
                </button>
                <button class="btn-icon btn-danger" onclick="deleteNote(${note.id})" title="删除">
                    🗑️
                </button>
            </div>
        </div>
    `;
    
    return card;
}

// 查看笔记详情
async function viewNote(noteId) {
    try {
        showLoading(true);
        const note = await contract.getNoteById(noteId);
        
        document.getElementById('viewTitle').textContent = note.title;
        document.getElementById('viewContent').textContent = note.content;
        
        const timestamp = new Date(note.timestamp.toNumber() * 1000);
        document.getElementById('viewTimestamp').textContent = '🕒 ' + formatDate(timestamp);
        document.getElementById('viewId').textContent = 'ID: #' + note.id.toString();
        
        currentViewNoteId = noteId;
        document.getElementById('viewModal').classList.remove('hidden');
    } catch (error) {
        console.error('View note error:', error);
        showToast('加载笔记失败: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

// 从查看模式进入编辑
function editNoteFromView() {
    closeViewModal();
    openEditNoteModal(currentViewNoteId);
}

// 从查看模式删除
function deleteNoteFromView() {
    const noteId = currentViewNoteId;
    closeViewModal();
    deleteNote(noteId);
}

// 打开创建笔记模态框
function openCreateNoteModal() {
    currentEditNoteId = null;
    document.getElementById('modalTitle').textContent = '新建笔记';
    document.getElementById('noteId').value = '';
    document.getElementById('noteTitle').value = '';
    document.getElementById('noteContent').value = '';
    document.getElementById('contentLength').textContent = '0';
    document.getElementById('noteModal').classList.remove('hidden');
    document.getElementById('noteTitle').focus();
}

// 打开编辑笔记模态框
async function openEditNoteModal(noteId) {
    try {
        showLoading(true);
        const note = await contract.getNoteById(noteId);
        
        currentEditNoteId = noteId;
        document.getElementById('modalTitle').textContent = '编辑笔记';
        document.getElementById('noteId').value = noteId;
        document.getElementById('noteTitle').value = note.title;
        document.getElementById('noteContent').value = note.content;
        document.getElementById('contentLength').textContent = note.content.length;
        document.getElementById('noteModal').classList.remove('hidden');
        document.getElementById('noteTitle').focus();
    } catch (error) {
        console.error('Open edit modal error:', error);
        showToast('加载笔记失败: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

// 关闭笔记模态框
function closeNoteModal() {
    document.getElementById('noteModal').classList.add('hidden');
    currentEditNoteId = null;
}

// 关闭查看模态框
function closeViewModal() {
    document.getElementById('viewModal').classList.add('hidden');
    currentViewNoteId = null;
}

// 处理保存笔记
async function handleSaveNote(e) {
    e.preventDefault();
    
    const title = document.getElementById('noteTitle').value.trim();
    const content = document.getElementById('noteContent').value.trim();
    const noteId = currentEditNoteId;
    
    if (!title) {
        showToast('请输入标题', 'error');
        return;
    }
    
    try {
        showLoading(true);
        let tx;
        
        if (noteId === null) {
            // 创建新笔记
            tx = await contract.createNote(title, content);
            showToast('正在创建笔记...', 'info');
        } else {
            // 更新笔记
            tx = await contract.updateNote(noteId, title, content);
            showToast('正在更新笔记...', 'info');
        }
        
        await tx.wait();
        
        showToast(noteId === null ? '笔记创建成功！' : '笔记更新成功！', 'success');
        closeNoteModal();
        await loadNotes();
    } catch (error) {
        console.error('Save note error:', error);
        if (error.code === 4001) {
            showToast('用户取消了交易', 'error');
        } else {
            showToast('保存失败: ' + error.message, 'error');
        }
    } finally {
        showLoading(false);
    }
}

// 删除笔记
async function deleteNote(noteId) {
    if (!confirm('确定要删除这条笔记吗？此操作不可撤销。')) {
        return;
    }
    
    try {
        showLoading(true);
        const tx = await contract.deleteNote(noteId);
        showToast('正在删除笔记...', 'info');
        await tx.wait();
        
        showToast('笔记删除成功！', 'success');
        
        // 如果当前页没有笔记了，回到上一页
        const notes = document.querySelectorAll('.note-card');
        if (notes.length === 1 && currentPage > 0) {
            currentPage--;
        }
        
        await loadNotes();
    } catch (error) {
        console.error('Delete note error:', error);
        if (error.code === 4001) {
            showToast('用户取消了交易', 'error');
        } else {
            showToast('删除失败: ' + error.message, 'error');
        }
    } finally {
        showLoading(false);
    }
}

// 更新分页
function updatePagination(notesCount, hasMore) {
    const paginationControls = document.getElementById('paginationControls');
    const prevBtn = document.getElementById('prevPage');
    const nextBtn = document.getElementById('nextPage');
    const pageInfo = document.getElementById('pageInfo');
    
    if (currentPage === 0 && !hasMore) {
        paginationControls.classList.add('hidden');
        return;
    }
    
    paginationControls.classList.remove('hidden');
    prevBtn.disabled = currentPage === 0;
    nextBtn.disabled = !hasMore;
    
    pageInfo.textContent = `第 ${currentPage + 1} 页`;
}

// 翻页
function changePage(delta) {
    currentPage += delta;
    if (currentPage < 0) currentPage = 0;
    loadNotes();
}

// 显示加载状态
function showLoading(show) {
    const spinner = document.getElementById('loadingSpinner');
    if (show) {
        spinner.classList.remove('hidden');
    } else {
        spinner.classList.add('hidden');
    }
}

// 显示 Toast 提示
function showToast(message, type = 'info') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast ${type}`;
    toast.classList.remove('hidden');
    
    setTimeout(() => {
        toast.classList.add('hidden');
    }, 3000);
}

// 格式化日期
function formatDate(date) {
    const now = new Date();
    const diff = now - date;
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) {
        return `${days} 天前`;
    } else if (hours > 0) {
        return `${hours} 小时前`;
    } else if (minutes > 0) {
        return `${minutes} 分钟前`;
    } else {
        return '刚刚';
    }
}

// HTML 转义
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
