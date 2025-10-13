
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Note {
    // 定义记事结构
    struct NoteRecord {
        string title;      // 标题
        string content;    // 内容
        uint256 timestamp; // 时间戳
        uint256 id;        // 记录ID
        string[] tags;     // tag
    }

    // 用户地址 => 记事记录数组
    mapping(address => NoteRecord[]) private userNotes;

    // 事件：当创建新记录时触发
    event NoteCreated(
        address indexed user,
        uint256 indexed noteId,
        string title,
        uint256 timestamp
    );

    // 事件：当给 note 添加 tag 时触发
    event NoteAddTag(
        address indexed user,
        uint256 indexed noteId,
        string tag,
        uint256 timestamp
    );

    constructor() {

    }

    /**
     * @dev 创建新的记事记录
     * @param _title 标题
     * @param _content 内容
     */
    function createNote(string memory _title, string memory _content) public {
        uint256 noteId = userNotes[msg.sender].length;

        NoteRecord memory newNote = NoteRecord({
            title: _title,
            content: _content,
            timestamp: block.timestamp,
            id: noteId,
            tags: new string[](0)  // 修复：使用 new string[](0) 初始化空数组
        });

        userNotes[msg.sender].push(newNote);

        emit NoteCreated(msg.sender, noteId, _title, block.timestamp);
    }

    /**
     * @dev 给已有的 note 增加 tag
     * @param _noteId 记录 ID
     * @param _tag tag 的值, 可以自定义
     */
    function addTag(uint256 _noteId, string memory _tag) public{
        require(bytes(_tag).length > 0, "tag cannot be empty");  // 修复：使用 bytes(_tag).length 检查空字符串
        require(_noteId < userNotes[msg.sender].length, "Note does not exist");  // 修复：添加边界检查
        
        userNotes[msg.sender][_noteId].tags.push(_tag);  // 修复：直接访问 storage
        
        emit NoteAddTag(msg.sender, _noteId, _tag, block.timestamp);
    }

    /**
     * @dev 获取指定用户的所有记事记录
     * @param _user 用户地址
     * @return 该用户的所有记事记录
     */
    function getAllNotes(address _user) public view returns (NoteRecord[] memory) {
        return userNotes[_user];
    }

    /**
     * @dev 获取当前调用者的所有记事记录
     * @return 当前用户的所有记事记录
     */
    function getMyNotes() public view returns (NoteRecord[] memory) {
        return userNotes[msg.sender];
    }

    /**
     * @dev 获取指定用户的某条特定记录
     * @param _user 用户地址
     * @param _noteId 记录ID
     * @return 指定的记事记录
     */
    function getNote(address _user, uint256 _noteId) public view returns (NoteRecord memory) {
        require(_noteId < userNotes[_user].length, "Note does not exist");
        return userNotes[_user][_noteId];
    }

    /**
     * @dev 获取指定用户的记事记录数量
     * @param _user 用户地址
     * @return 记录数量
     */
    function getNoteCount(address _user) public view returns (uint256) {
        return userNotes[_user].length;
    }
}