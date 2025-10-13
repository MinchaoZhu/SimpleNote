// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Note} from "../src/NoteManagement.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract NoteManagementTest is Test {
    Note public note;

    // 测试用户地址
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    // 测试数据
    string constant TITLE1 = "First Note";
    string constant CONTENT1 = "This is my first note content";
    string constant TITLE2 = "Second Note";
    string constant CONTENT2 = "This is my second note content";

    // 事件声明（用于测试事件触发）
    event NoteCreated(
        address indexed user,
        uint256 indexed noteId,
        string title,
        uint256 timestamp
    );

    // 添加 addTag 事件声明
    event NoteAddTag(
        address indexed user,
        uint256 indexed noteId,
        string tag,
        uint256 timestamp
    );

    function setUp() public {
        note = new Note();
    }

    /// 测试：创建单条记录
    function test_CreateNote() public {
        vm.prank(user1);
        note.createNote(TITLE1, CONTENT1);

        // 验证记录数量
        uint256 count = note.getNoteCount(user1);
        assertEq(count, 1, "Note count should be 1");

        // 验证记录内容
        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.title, TITLE1, "Title should match");
        assertEq(record.content, CONTENT1, "Content should match");
        assertEq(record.id, 0, "ID should be 0");
        assertGt(record.timestamp, 0, "Timestamp should be set");
    }

    /// 测试：创建多条记录
    function test_CreateMultipleNotes() public {
        vm.startPrank(user1);
        note.createNote(TITLE1, CONTENT1);
        note.createNote(TITLE2, CONTENT2);
        vm.stopPrank();

        // 验证记录数量
        uint256 count = note.getNoteCount(user1);
        assertEq(count, 2, "Note count should be 2");

        // 验证第一条记录
        Note.NoteRecord memory record1 = note.getNote(user1, 0);
        assertEq(record1.title, TITLE1, "First note title should match");
        assertEq(record1.id, 0, "First note ID should be 0");

        // 验证第二条记录
        Note.NoteRecord memory record2 = note.getNote(user1, 1);
        assertEq(record2.title, TITLE2, "Second note title should match");
        assertEq(record2.id, 1, "Second note ID should be 1");
    }

    /// 测试：不同用户创建记录互不影响
    function test_MultipleUsersCreateNotes() public {
        // user1 创建记录
        vm.prank(user1);
        note.createNote("User1 Note", "User1 Content");

        // user2 创建记录
        vm.prank(user2);
        note.createNote("User2 Note", "User2 Content");

        // 验证各自的记录数量
        assertEq(note.getNoteCount(user1), 1, "User1 should have 1 note");
        assertEq(note.getNoteCount(user2), 1, "User2 should have 1 note");

        // 验证各自的记录内容
        Note.NoteRecord memory user1Record = note.getNote(user1, 0);
        assertEq(user1Record.title, "User1 Note", "User1 note title should match");

        Note.NoteRecord memory user2Record = note.getNote(user2, 0);
        assertEq(user2Record.title, "User2 Note", "User2 note title should match");
    }

    /// 测试：获取所有记录
    function test_GetAllNotes() public {
        vm.startPrank(user1);
        note.createNote(TITLE1, CONTENT1);
        note.createNote(TITLE2, CONTENT2);
        vm.stopPrank();

        // 获取所有记录
        Note.NoteRecord[] memory allNotes = note.getAllNotes(user1);

        assertEq(allNotes.length, 2, "Should return 2 notes");
        assertEq(allNotes[0].title, TITLE1, "First note title should match");
        assertEq(allNotes[1].title, TITLE2, "Second note title should match");
    }

    /// 测试：获取我的记录
    function test_GetMyNotes() public {
        vm.startPrank(user1);
        note.createNote(TITLE1, CONTENT1);

        // 使用 getMyNotes 获取当前用户的记录
        Note.NoteRecord[] memory myNotes = note.getMyNotes();

        assertEq(myNotes.length, 1, "Should return 1 note");
        assertEq(myNotes[0].title, TITLE1, "Note title should match");
        vm.stopPrank();
    }

    /// 测试：获取不存在的记录应该失败
    function test_GetNonExistentNote_ShouldRevert() public {
        vm.expectRevert("Note does not exist");
        note.getNote(user1, 0);
    }

    /// 测试：获取超出范围的记录应该失败
    function test_GetOutOfBoundsNote_ShouldRevert() public {
        vm.prank(user1);
        note.createNote(TITLE1, CONTENT1);

        vm.expectRevert("Note does not exist");
        note.getNote(user1, 1); // 只有索引 0，访问索引 1 应该失败
    }

    /// 测试：事件触发
    function test_NoteCreatedEvent() public {
        // 预期事件触发
        vm.expectEmit(true, true, false, false);
        emit NoteCreated(user1, 0, TITLE1, block.timestamp);

        vm.prank(user1);
        note.createNote(TITLE1, CONTENT1);
    }

    /// 测试：空标题和内容
    function test_CreateNoteWithEmptyStrings() public {
        vm.prank(user1);
        note.createNote("", "");

        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.title, "", "Empty title should be stored");
        assertEq(record.content, "", "Empty content should be stored");
    }

    /// 测试：获取记录数量（空）
    function test_GetNoteCountEmpty() public {
        uint256 count = note.getNoteCount(user1);
        assertEq(count, 0, "Initial note count should be 0");
    }

    /// 测试：时间戳递增
    function test_TimestampIncreases() public {
        vm.startPrank(user1);

        note.createNote(TITLE1, CONTENT1);
        Note.NoteRecord memory note1 = note.getNote(user1, 0);

        // 前进时间
        vm.warp(block.timestamp + 100);

        note.createNote(TITLE2, CONTENT2);
        Note.NoteRecord memory note2 = note.getNote(user1, 1);

        vm.stopPrank();

        assertLt(note1.timestamp, note2.timestamp, "Second note timestamp should be greater");
    }

    /// Fuzz 测试：任意标题和内容
    function testFuzz_CreateNoteWithArbitraryData(string memory title, string memory content) public {
        vm.prank(user1);
        note.createNote(title, content);

        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.title, title, "Title should match");
        assertEq(record.content, content, "Content should match");
    }

    /// Fuzz 测试：多个用户创建记录
    function testFuzz_MultipleUsersCreateNotes(address user, string memory title) public {
        vm.assume(user != address(0)); // 排除零地址

        vm.prank(user);
        note.createNote(title, "content");

        assertEq(note.getNoteCount(user), 1, "User should have 1 note");
    }

    /// 测试：大量记录创建
    function test_CreateManyNotes() public {
        vm.startPrank(user1);

        uint256 noteCount = 10;
        for (uint256 i = 0; i < noteCount; i++) {
            note.createNote(
                string(abi.encodePacked("Title ", i)),
                string(abi.encodePacked("Content ", i))
            );
        }

        vm.stopPrank();

        assertEq(note.getNoteCount(user1), noteCount, "Should have created 10 notes");

        // 验证最后一条记录
        Note.NoteRecord memory lastNote = note.getNote(user1, noteCount - 1);
        assertEq(lastNote.id, noteCount - 1, "Last note ID should match");
    }

    /// ========== addTag 测试 ==========

    /// 测试：给 note 添加单个 tag
    function test_AddSingleTag() public {
        // 先创建一个 note
        vm.prank(user1);
        note.createNote(TITLE1, CONTENT1);

        // 添加 tag
        vm.prank(user1);
        note.addTag(0, "important");

        // 验证 tag 已添加
        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.tags.length, 1, "Should have 1 tag");
        assertEq(record.tags[0], "important", "Tag should match");
    }

    /// 测试：给 note 添加多个 tags
    function test_AddMultipleTags() public {
        vm.startPrank(user1);
        
        // 创建 note
        note.createNote(TITLE1, CONTENT1);
        
        // 添加多个 tags
        note.addTag(0, "important");
        note.addTag(0, "work");
        note.addTag(0, "urgent");
        
        vm.stopPrank();

        // 验证所有 tags
        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.tags.length, 3, "Should have 3 tags");
        assertEq(record.tags[0], "important", "First tag should match");
        assertEq(record.tags[1], "work", "Second tag should match");
        assertEq(record.tags[2], "urgent", "Third tag should match");
    }

    /// 测试：添加空 tag 应该失败
    function test_AddEmptyTag_ShouldRevert() public {
        vm.startPrank(user1);
        
        // 创建 note
        note.createNote(TITLE1, CONTENT1);
        
        // 尝试添加空 tag
        vm.expectRevert("tag cannot be empty");
        note.addTag(0, "");
        
        vm.stopPrank();
    }

    /// 测试：给不存在的 note 添加 tag 应该失败
    function test_AddTagToNonExistentNote_ShouldRevert() public {
        vm.prank(user1);
        vm.expectRevert("Note does not exist");
        note.addTag(0, "important");
    }

    /// 测试：给超出范围的 note 添加 tag 应该失败
    function test_AddTagToOutOfBoundsNote_ShouldRevert() public {
        vm.startPrank(user1);
        
        // 创建一个 note
        note.createNote(TITLE1, CONTENT1);
        
        // 尝试给索引 1 的 note 添加 tag（不存在）
        vm.expectRevert("Note does not exist");
        note.addTag(1, "important");
        
        vm.stopPrank();
    }

    /// 测试：不同用户给各自的 note 添加 tag
    function test_DifferentUsersAddTags() public {
        // user1 创建 note 并添加 tag
        vm.startPrank(user1);
        note.createNote("User1 Note", "User1 Content");
        note.addTag(0, "user1-tag");
        vm.stopPrank();

        // user2 创建 note 并添加 tag
        vm.startPrank(user2);
        note.createNote("User2 Note", "User2 Content");
        note.addTag(0, "user2-tag");
        vm.stopPrank();

        // 验证 user1 的 tag
        Note.NoteRecord memory user1Record = note.getNote(user1, 0);
        assertEq(user1Record.tags.length, 1, "User1 should have 1 tag");
        assertEq(user1Record.tags[0], "user1-tag", "User1 tag should match");

        // 验证 user2 的 tag
        Note.NoteRecord memory user2Record = note.getNote(user2, 0);
        assertEq(user2Record.tags.length, 1, "User2 should have 1 tag");
        assertEq(user2Record.tags[0], "user2-tag", "User2 tag should match");
    }

    /// 测试：给多条 notes 分别添加 tags
    function test_AddTagsToMultipleNotes() public {
        vm.startPrank(user1);
        
        // 创建两条 notes
        note.createNote(TITLE1, CONTENT1);
        note.createNote(TITLE2, CONTENT2);
        
        // 给第一条 note 添加 tags
        note.addTag(0, "tag1");
        note.addTag(0, "tag2");
        
        // 给第二条 note 添加 tags
        note.addTag(1, "tag3");
        note.addTag(1, "tag4");
        
        vm.stopPrank();

        // 验证第一条 note 的 tags
        Note.NoteRecord memory note1 = note.getNote(user1, 0);
        assertEq(note1.tags.length, 2, "First note should have 2 tags");
        assertEq(note1.tags[0], "tag1", "First note first tag should match");
        assertEq(note1.tags[1], "tag2", "First note second tag should match");

        // 验证第二条 note 的 tags
        Note.NoteRecord memory note2 = note.getNote(user1, 1);
        assertEq(note2.tags.length, 2, "Second note should have 2 tags");
        assertEq(note2.tags[0], "tag3", "Second note first tag should match");
        assertEq(note2.tags[1], "tag4", "Second note second tag should match");
    }

    /// 测试：addTag 事件触发
    function test_NoteAddTagEvent() public {
        vm.startPrank(user1);
        
        // 创建 note
        note.createNote(TITLE1, CONTENT1);
        
        // 预期事件触发
        vm.expectEmit(true, true, false, true);
        emit NoteAddTag(user1, 0, "important", block.timestamp);
        
        // 添加 tag
        note.addTag(0, "important");
        
        vm.stopPrank();
    }

    /// 测试：添加相同的 tag（允许重复）
    function test_AddDuplicateTags() public {
        vm.startPrank(user1);
        
        // 创建 note
        note.createNote(TITLE1, CONTENT1);
        
        // 添加相同的 tag 多次
        note.addTag(0, "important");
        note.addTag(0, "important");
        
        vm.stopPrank();

        // 验证：允许重复的 tag
        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.tags.length, 2, "Should have 2 tags (duplicates allowed)");
        assertEq(record.tags[0], "important", "First tag should match");
        assertEq(record.tags[1], "important", "Second tag should match");
    }

    /// Fuzz 测试：任意 tag 内容
    function testFuzz_AddTagWithArbitraryData(string memory tag) public {
        // 假设 tag 不为空
        vm.assume(bytes(tag).length > 0);
        
        vm.startPrank(user1);
        
        // 创建 note
        note.createNote(TITLE1, CONTENT1);
        
        // 添加任意 tag
        note.addTag(0, tag);
        
        vm.stopPrank();

        // 验证 tag
        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.tags.length, 1, "Should have 1 tag");
        assertEq(record.tags[0], tag, "Tag should match");
    }

    /// 测试：创建 note 时 tags 为空数组
    function test_NewNoteHasEmptyTags() public {
        vm.prank(user1);
        note.createNote(TITLE1, CONTENT1);

        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.tags.length, 0, "New note should have empty tags array");
    }

    /// 测试：大量 tags 添加
    function test_AddManyTags() public {
        vm.startPrank(user1);
        
        // 创建 note
        note.createNote(TITLE1, CONTENT1);
        
        // 添加大量 tags
        uint256 tagCount = 20;
        for (uint256 i = 0; i < tagCount; i++) {
            note.addTag(0, string(abi.encodePacked("tag", Strings.toString(i))));
        }
        
        vm.stopPrank();

        // 验证所有 tags
        Note.NoteRecord memory record = note.getNote(user1, 0);
        assertEq(record.tags.length, tagCount, "Should have 20 tags actual");
        
        // 验证第一个和最后一个 tag
        assertEq(record.tags[0], "tag0", string(abi.encodePacked("First tag should match, actual tag=", record.tags[0])));
        assertEq(record.tags[tagCount - 1], string(abi.encodePacked("tag", Strings.toString(tagCount - 1))), "Last tag should match");
    }
}
