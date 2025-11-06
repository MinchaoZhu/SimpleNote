// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NoteManagement} from "../src/NoteManagement.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title NoteManagementTest
 * @dev Comprehensive test suite for the NoteManagement contract including CRUD operations,
 * property management, pagination, validation, and security tests
 */
contract NoteManagementTest is Test {
    RandomArray public randomArray;
    NoteManagement public implementation;
    ERC1967Proxy public proxy;
    NoteManagement public noteManagement;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    // Events from the contract
    event NoteCreated(uint256 indexed id, address indexed owner, uint256 timestamp);
    event NoteUpdated(uint256 indexed id, uint256 timestamp);
    event NoteDeleted(uint256 indexed id);

    function setUp() public {
        randomArray = new RandomArray();

        // Deploy implementation
        implementation = new NoteManagement();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(NoteManagement.initialize.selector);
        proxy = new ERC1967Proxy(address(implementation), initData);
        noteManagement = NoteManagement(address(proxy));
    }

    // ========== Note Creation Tests ==========

    function testCreateNote() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, false);
        emit NoteCreated(0, user1, block.timestamp);

        noteManagement.createNote("My First Note", "This is the content");

        assertEq(noteManagement.getTotalNotesCount(), 1);
        assertEq(noteManagement.getUserNotesCount(), 1);

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.id, 0);
        assertEq(note.owner, user1);
        assertEq(note.title, "My First Note");
        assertEq(note.content, "This is the content");
        assertTrue(note.isValid);
        assertEq(note.propertyKeys.length, 0);

        vm.stopPrank();
    }

    function testCreateMultipleNotes() public {
        vm.startPrank(user1);

        noteManagement.createNote("Note 1", "Content 1");
        noteManagement.createNote("Note 2", "Content 2");
        noteManagement.createNote("Note 3", "Content 3");

        assertEq(noteManagement.getTotalNotesCount(), 3);
        assertEq(noteManagement.getUserNotesCount(), 3);

        vm.stopPrank();
    }

    function testCreateNoteByDifferentUsers() public {
        vm.prank(user1);
        noteManagement.createNote("User1 Note", "User1 Content");

        vm.prank(user2);
        noteManagement.createNote("User2 Note", "User2 Content");

        assertEq(noteManagement.getTotalNotesCount(), 2);

        vm.prank(user1);
        assertEq(noteManagement.getUserNotesCount(), 1);

        vm.prank(user2);
        assertEq(noteManagement.getUserNotesCount(), 1);
    }

    function testCreateNoteWithEmptyContent() public {
        vm.startPrank(user1);

        noteManagement.createNote("Title Only", "");
        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.title, "Title Only");
        assertEq(note.content, "");

        vm.stopPrank();
    }

    function testCreateNoteInvalidTitleTooShort() public {
        vm.startPrank(user1);

        vm.expectRevert("Invalid string length");
        noteManagement.createNote("", "Valid content");

        vm.stopPrank();
    }

    function testCreateNoteInvalidTitleTooLong() public {
        vm.startPrank(user1);

        // Create a title longer than 256 characters
        string memory longTitle = "";
        for (uint256 i = 0; i < 26; i++) {
            longTitle = string.concat(longTitle, "0123456789");
        }

        vm.expectRevert("Invalid string length");
        noteManagement.createNote(longTitle, "Valid content");

        vm.stopPrank();
    }

    function testCreateNoteInvalidContentTooLong() public {
        vm.startPrank(user1);

        // Create content longer than 20480 characters
        string memory longContent = "";
        for (uint256 i = 0; i < 2049; i++) {
            longContent = string.concat(longContent, "0123456789");
        }

        vm.expectRevert("Invalid string length");
        noteManagement.createNote("Valid title", longContent);

        vm.stopPrank();
    }

    // ========== Note Retrieval Tests ==========

    function testGetNoteById() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);

        assertEq(note.id, 0);
        assertEq(note.title, "Test Note");
        assertEq(note.content, "Test Content");

        vm.stopPrank();
    }

    function testGetNoteByIdNonExistent() public {
        vm.startPrank(user1);

        vm.expectRevert("Note does not exist");
        noteManagement.getNoteById(999);

        vm.stopPrank();
    }

    function testGetNoteByIdDeleted() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.deleteNote(0);

        vm.expectRevert("Note is deleted");
        noteManagement.getNoteById(0);

        vm.stopPrank();
    }

    // ========== Pagination Tests ==========

    function testGetUserNotesWithPageEmpty() public {
        vm.startPrank(user1);

        (NoteManagement.NoteRecord[] memory notes, uint256 nextOffset, bool hasMore) =
            noteManagement.getUserNotesWithPage(0, 10);

        assertEq(notes.length, 0);
        assertEq(nextOffset, 0);
        assertFalse(hasMore);

        vm.stopPrank();
    }

    function testGetUserNotesWithPageSinglePage() public {
        vm.startPrank(user1);

        // Create 5 notes
        for (uint256 i = 0; i < 5; i++) {
            noteManagement.createNote(
                string.concat("Note ", Strings.toString(i)), string.concat("Content ", Strings.toString(i))
            );
        }

        (NoteManagement.NoteRecord[] memory notes, uint256 nextOffset, bool hasMore) =
            noteManagement.getUserNotesWithPage(0, 10);

        assertEq(notes.length, 5);
        assertEq(nextOffset, 5);
        assertFalse(hasMore);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(notes[i].title, string.concat("Note ", Strings.toString(i)));
        }

        vm.stopPrank();
    }

    function testGetUserNotesWithPageMultiplePages() public {
        vm.startPrank(user1);

        // Create 15 notes
        for (uint256 i = 0; i < 15; i++) {
            noteManagement.createNote(
                string.concat("Note ", Strings.toString(i)), string.concat("Content ", Strings.toString(i))
            );
        }

        // First page
        (NoteManagement.NoteRecord[] memory notes1, uint256 nextOffset1, bool hasMore1) =
            noteManagement.getUserNotesWithPage(0, 5);

        assertEq(notes1.length, 5);
        assertEq(nextOffset1, 5);
        assertTrue(hasMore1);

        // Second page
        (NoteManagement.NoteRecord[] memory notes2, uint256 nextOffset2, bool hasMore2) =
            noteManagement.getUserNotesWithPage(5, 5);

        assertEq(notes2.length, 5);
        assertEq(nextOffset2, 10);
        assertTrue(hasMore2);

        // Third page
        (NoteManagement.NoteRecord[] memory notes3, uint256 nextOffset3, bool hasMore3) =
            noteManagement.getUserNotesWithPage(10, 5);

        assertEq(notes3.length, 5);
        assertEq(nextOffset3, 15);
        assertFalse(hasMore3);

        vm.stopPrank();
    }

    function testGetUserNotesWithPageInvalidLimit() public {
        vm.startPrank(user1);

        vm.expectRevert("Invalid limit");
        noteManagement.getUserNotesWithPage(0, 0);

        vm.expectRevert("Invalid limit");
        noteManagement.getUserNotesWithPage(0, 25);

        vm.stopPrank();
    }

    function testGetUserNotesWithPageOffsetBeyondRange() public {
        vm.startPrank(user1);

        noteManagement.createNote("Note 1", "Content 1");

        (NoteManagement.NoteRecord[] memory notes, uint256 nextOffset, bool hasMore) =
            noteManagement.getUserNotesWithPage(5, 10);

        assertEq(notes.length, 0);
        assertEq(nextOffset, 1);
        assertFalse(hasMore);

        vm.stopPrank();
    }

    // ========== Legacy getUserNotes Tests ==========

    function testGetUserNotesEmpty() public {
        vm.startPrank(user1);

        (NoteManagement.NoteRecord[] memory notes,,) = noteManagement.getUserNotesWithPage(0, 20);
        assertEq(notes.length, 0);

        vm.stopPrank();
    }

    function testGetUserNotesAfterDelete() public {
        vm.startPrank(user1);

        noteManagement.createNote("Note 1", "Content 1");
        noteManagement.createNote("Note 2", "Content 2");
        noteManagement.deleteNote(0);

        (NoteManagement.NoteRecord[] memory notes,,) = noteManagement.getUserNotesWithPage(0, 20);
        assertEq(notes.length, 1);
        assertEq(notes[0].title, "Note 2");

        vm.stopPrank();
    }

    // ========== Note Update Tests ==========

    function testUpdateNote() public {
        vm.startPrank(user1);

        noteManagement.createNote("Original Title", "Original Content");

        uint256 originalTimestamp = block.timestamp;
        vm.warp(block.timestamp + 100);

        vm.expectEmit(true, false, false, false);
        emit NoteUpdated(0, block.timestamp);

        noteManagement.updateNote(0, "Updated Title", "Updated Content");

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.title, "Updated Title");
        assertEq(note.content, "Updated Content");
        assertTrue(note.timestamp > originalTimestamp);

        vm.stopPrank();
    }

    function testUpdateNoteNotOwner() public {
        vm.prank(user1);
        noteManagement.createNote("User1 Note", "User1 Content");

        vm.prank(user2);
        vm.expectRevert("Not the note owner");
        noteManagement.updateNote(0, "Hacked Title", "Hacked Content");
    }

    function testUpdateNonExistentNote() public {
        vm.startPrank(user1);

        vm.expectRevert("Note does not exist");
        noteManagement.updateNote(999, "Title", "Content");

        vm.stopPrank();
    }

    function testUpdateDeletedNote() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.deleteNote(0);

        vm.expectRevert("Note is deleted");
        noteManagement.updateNote(0, "New Title", "New Content");

        vm.stopPrank();
    }

    // ========== Note Deletion Tests ==========

    function testDeleteNote() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        vm.expectEmit(true, false, false, false);
        emit NoteDeleted(0);

        noteManagement.deleteNote(0);

        assertEq(noteManagement.getUserNotesCount(), 0);

        vm.expectRevert("Note is deleted");
        noteManagement.getNoteById(0);

        vm.stopPrank();
    }

    function testDeleteNoteNotOwner() public {
        vm.prank(user1);
        noteManagement.createNote("User1 Note", "User1 Content");

        vm.prank(user2);
        vm.expectRevert("Not the note owner");
        noteManagement.deleteNote(0);
    }

    function testDeleteNonExistentNote() public {
        vm.startPrank(user1);

        vm.expectRevert("Note does not exist");
        noteManagement.deleteNote(999);

        vm.stopPrank();
    }

    function testDeleteAlreadyDeletedNote() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.deleteNote(0);

        vm.expectRevert("Note is deleted");
        noteManagement.deleteNote(0);

        vm.stopPrank();
    }

    // ========== Property Management Tests ==========

    function testAddProperty() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.addProperty(0, "priority", "high");
        noteManagement.addProperty(0, "category", "work");

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.propertyKeys.length, 2);
        assertEq(note.propertyKeys[0], "priority");
        assertEq(note.propertyKeys[1], "category");

        assertEq(noteManagement.getProperty(0, "priority"), "high");
        assertEq(noteManagement.getProperty(0, "category"), "work");

        vm.stopPrank();
    }

    function testAddPropertyOverwrite() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.addProperty(0, "priority", "low");
        noteManagement.addProperty(0, "priority", "high");

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.propertyKeys.length, 1);
        assertEq(note.propertyKeys[0], "priority");
        assertEq(noteManagement.getProperty(0, "priority"), "high");

        vm.stopPrank();
    }

    function testAddPropertyInvalidKeyTooShort() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        vm.expectRevert("Invalid string length");
        noteManagement.addProperty(0, "", "value");

        vm.stopPrank();
    }

    function testAddPropertyInvalidKeyTooLong() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        // Create a key longer than 32 characters
        string memory longKey = "this_is_a_very_long_property_key_that_exceeds_limit";

        vm.expectRevert("Invalid string length");
        noteManagement.addProperty(0, longKey, "value");

        vm.stopPrank();
    }

    function testAddPropertyInvalidValueTooShort() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        vm.expectRevert("Invalid string length");
        noteManagement.addProperty(0, "key", "");

        vm.stopPrank();
    }

    function testAddPropertyInvalidValueTooLong() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        // Create a value longer than 2048 characters
        string memory longValue = "";
        for (uint256 i = 0; i < 205; i++) {
            longValue = string.concat(longValue, "0123456789");
        }

        vm.expectRevert("Invalid string length");
        noteManagement.addProperty(0, "key", longValue);

        vm.stopPrank();
    }

    function testAddPropertyTooManyProperties() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        // Add maximum allowed properties (32)
        for (uint256 i = 0; i < 32; i++) {
            noteManagement.addProperty(0, string.concat("key", Strings.toString(i)), "value");
        }

        // Adding the 33rd property should fail
        vm.expectRevert("Too many properties");
        noteManagement.addProperty(0, "key33", "value");

        vm.stopPrank();
    }

    function testAddPropertyNotOwner() public {
        vm.prank(user1);
        noteManagement.createNote("User1 Note", "User1 Content");

        vm.prank(user2);
        vm.expectRevert("Not the note owner");
        noteManagement.addProperty(0, "key", "value");
    }

    function testAddPropertyToDeletedNote() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.deleteNote(0);

        vm.expectRevert("Note is deleted");
        noteManagement.addProperty(0, "key", "value");

        vm.stopPrank();
    }

    function testGetProperty() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.addProperty(0, "priority", "high");

        string memory value = noteManagement.getProperty(0, "priority");
        assertEq(value, "high");

        vm.stopPrank();
    }

    function testGetNonExistentProperty() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        string memory value = noteManagement.getProperty(0, "nonexistent");
        assertEq(value, "");

        vm.stopPrank();
    }

    function testGetAllProperties() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.addProperty(0, "priority", "high");
        noteManagement.addProperty(0, "category", "work");
        noteManagement.addProperty(0, "status", "active");

        (string[] memory keys, string[] memory values) = noteManagement.getAllProperties(0);

        assertEq(keys.length, 3);
        assertEq(values.length, 3);
        assertEq(keys[0], "priority");
        assertEq(values[0], "high");
        assertEq(keys[1], "category");
        assertEq(values[1], "work");
        assertEq(keys[2], "status");
        assertEq(values[2], "active");

        vm.stopPrank();
    }

    function testGetAllPropertiesEmpty() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        (string[] memory keys, string[] memory values) = noteManagement.getAllProperties(0);

        assertEq(keys.length, 0);
        assertEq(values.length, 0);

        vm.stopPrank();
    }

    function testDeleteProperty() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.addProperty(0, "priority", "high");
        noteManagement.addProperty(0, "category", "work");
        noteManagement.addProperty(0, "status", "active");

        noteManagement.deleteProperty(0, "category");

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.propertyKeys.length, 2);

        (string[] memory keys, string[] memory values) = noteManagement.getAllProperties(0);
        assertEq(keys.length, 2);
        assertEq(values.length, 2);

        // Ensure deleted property doesn't exist
        string memory deletedValue = noteManagement.getProperty(0, "category");
        assertEq(deletedValue, "");

        // Ensure other properties still exist
        assertEq(noteManagement.getProperty(0, "priority"), "high");
        assertEq(noteManagement.getProperty(0, "status"), "active");

        vm.stopPrank();
    }

    function testDeleteNonExistentProperty() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        vm.expectRevert("Property does not exist");
        noteManagement.deleteProperty(0, "nonexistent");

        vm.stopPrank();
    }

    function testDeletePropertyNotOwner() public {
        vm.prank(user1);
        noteManagement.createNote("User1 Note", "User1 Content");
        vm.prank(user1);
        noteManagement.addProperty(0, "key", "value");

        vm.prank(user2);
        vm.expectRevert("Not the note owner");
        noteManagement.deleteProperty(0, "key");
    }

    function testDeletePropertyFromDeletedNote() public {
        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        noteManagement.addProperty(0, "key", "value");
        noteManagement.deleteNote(0);

        vm.expectRevert("Note is deleted");
        noteManagement.deleteProperty(0, "key");

        vm.stopPrank();
    }

    // ========== Count Function Tests ==========

    function testGetTotalNotesCount() public {
        assertEq(noteManagement.getTotalNotesCount(), 0);

        vm.prank(user1);
        noteManagement.createNote("Note 1", "Content 1");
        assertEq(noteManagement.getTotalNotesCount(), 1);

        vm.prank(user2);
        noteManagement.createNote("Note 2", "Content 2");
        assertEq(noteManagement.getTotalNotesCount(), 2);

        vm.prank(user1);
        noteManagement.deleteNote(0);
        // Total count should not change after deletion
        assertEq(noteManagement.getTotalNotesCount(), 2);
    }

    function testGetUserNotesCount() public {
        vm.startPrank(user1);

        assertEq(noteManagement.getUserNotesCount(), 0);

        noteManagement.createNote("Note 1", "Content 1");
        assertEq(noteManagement.getUserNotesCount(), 1);

        noteManagement.createNote("Note 2", "Content 2");
        assertEq(noteManagement.getUserNotesCount(), 2);

        noteManagement.deleteNote(0);
        assertEq(noteManagement.getUserNotesCount(), 1);

        vm.stopPrank();
    }

    // ========== Edge Cases and Security Tests ==========

    function testMultipleUsersIsolation() public {
        // User1 creates notes
        vm.startPrank(user1);
        noteManagement.createNote("User1 Note 1", "Content 1");
        noteManagement.createNote("User1 Note 2", "Content 2");
        vm.stopPrank();

        // User2 creates notes
        vm.startPrank(user2);
        noteManagement.createNote("User2 Note 1", "Content 1");
        vm.stopPrank();

        // Check isolation
        vm.prank(user1);
        assertEq(noteManagement.getUserNotesCount(), 2);

        vm.prank(user2);
        assertEq(noteManagement.getUserNotesCount(), 1);

        // User2 cannot access User1's notes through pagination
        vm.prank(user2);
        (NoteManagement.NoteRecord[] memory user2Notes,,) = noteManagement.getUserNotesWithPage(0, 20);
        assertEq(user2Notes.length, 1);
        assertEq(user2Notes[0].id, 2);
    }

    function testLongStrings() public {
        vm.startPrank(user1);

        string memory longTitle = "This is a very long title that contains many characters to test the system";
        string memory longContent =
            "This is a very long content with multiple sentences. It should test the storage and retrieval of lengthy text content in the blockchain.";

        noteManagement.createNote(longTitle, longContent);
        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);

        assertEq(note.title, longTitle);
        assertEq(note.content, longContent);

        vm.stopPrank();
    }

    // ========== Fuzz Tests ==========

    function testFuzzCreateNote(string calldata _title, string calldata _content) public {
        // Constrain inputs to valid ranges
        vm.assume(bytes(_title).length >= 1 && bytes(_title).length <= 256);
        vm.assume(bytes(_content).length <= 20480);

        vm.startPrank(user1);

        vm.expectEmit(true, true, false, false);
        emit NoteCreated(0, user1, block.timestamp);

        noteManagement.createNote(_title, _content);

        assertEq(noteManagement.getTotalNotesCount(), 1);
        assertEq(noteManagement.getUserNotesCount(), 1);

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.id, 0);
        assertEq(note.owner, user1);
        assertEq(note.title, _title);
        assertEq(note.content, _content);
        assertTrue(note.isValid);
        assertEq(note.propertyKeys.length, 0);

        vm.stopPrank();
    }

    function testFuzzCreateNoteByDifferentUsers(address _user1, address _user2) public {
        vm.assume(_user1 != _user2);

        vm.prank(_user1);
        noteManagement.createNote("User1 Note", "User1 Content");

        vm.prank(_user2);
        noteManagement.createNote("User2 Note", "User2 Content");

        assertEq(noteManagement.getTotalNotesCount(), 2);

        vm.prank(_user1);
        assertEq(noteManagement.getUserNotesCount(), 1);

        vm.prank(_user2);
        assertEq(noteManagement.getUserNotesCount(), 1);
    }

    function testFuzzUpdateNote(string calldata updatedTitle, string calldata updatedContent) public {
        // Constrain inputs to valid ranges
        vm.assume(bytes(updatedTitle).length >= 1 && bytes(updatedTitle).length <= 256);
        vm.assume(bytes(updatedContent).length <= 20480);

        vm.startPrank(user1);

        noteManagement.createNote("Original Title", "Original Content");

        uint256 originalTimestamp = block.timestamp;
        vm.warp(block.timestamp + 100);

        vm.expectEmit(true, false, false, false);
        emit NoteUpdated(0, block.timestamp);

        noteManagement.updateNote(0, updatedTitle, updatedContent);

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.title, updatedTitle);
        assertEq(note.content, updatedContent);
        assertTrue(note.timestamp > originalTimestamp);

        vm.stopPrank();
    }

    function testFuzzDeleteNote(string calldata _title, string calldata _content) public {
        // Constrain inputs to valid ranges
        vm.assume(bytes(_title).length >= 1 && bytes(_title).length <= 256);
        vm.assume(bytes(_content).length <= 20480);

        vm.startPrank(user1);

        noteManagement.createNote(_title, _content);

        vm.expectEmit(true, false, false, false);
        emit NoteDeleted(0);

        noteManagement.deleteNote(0);

        assertEq(noteManagement.getUserNotesCount(), 0);

        vm.expectRevert("Note is deleted");
        noteManagement.getNoteById(0);

        vm.stopPrank();
    }

    function testFuzzAddProperty(string calldata _key, string calldata _value, uint256 _count) public {
        // Constrain inputs to valid ranges
        vm.assume(bytes(_key).length >= 1 && bytes(_key).length <= 30);
        vm.assume(bytes(_value).length >= 1 && bytes(_value).length <= 2046);

        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");

        uint256 count = _count % 16; // Limit to prevent gas issues

        for (uint256 i = 0; i < count; i++) {
            noteManagement.addProperty(
                0, string.concat(_key, Strings.toString(i)), string.concat(_value, Strings.toString(i))
            );
        }

        NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);
        assertEq(note.propertyKeys.length, count);

        for (uint256 i = 0; i < count; i++) {
            string memory expectedKey = string.concat(_key, Strings.toString(i));
            string memory expectedValue = string.concat(_value, Strings.toString(i));
            assertEq(note.propertyKeys[i], expectedKey);
            assertEq(noteManagement.getProperty(0, expectedKey), expectedValue);
        }

        vm.stopPrank();
    }

    function testFuzzDeleteProperty(string calldata _key, string calldata _value, uint256 _count) public {
        // Constrain inputs to valid ranges
        vm.assume(bytes(_key).length >= 1 && bytes(_key).length <= 30);
        vm.assume(bytes(_value).length >= 1 && bytes(_value).length <= 2046);
        vm.assume(_count % 16 > 0);

        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        uint256 count = _count % 16;

        // Add properties
        for (uint256 i = 0; i < count; i++) {
            noteManagement.addProperty(
                0, string.concat(_key, Strings.toString(i)), string.concat(_value, Strings.toString(i))
            );
        }

        uint256[] memory seq = randomArray.generateAndShuffle(count);

        // Randomly delete properties
        for (uint256 i = 0; i < count; i++) {
            uint256 index = seq[i];
            string memory keyToDelete = string.concat(_key, Strings.toString(index));

            noteManagement.deleteProperty(0, keyToDelete);
            NoteManagement.NoteRecord memory note = noteManagement.getNoteById(0);

            assertEq(note.propertyKeys.length, count - i - 1);

            // Ensure deleted property no longer exists
            string memory deletedValue = noteManagement.getProperty(0, keyToDelete);
            assertEq(deletedValue, "");

            // Ensure remaining property keys don't contain deleted key
            for (uint256 j = 0; j < note.propertyKeys.length; j++) {
                assertNotEq(note.propertyKeys[j], keyToDelete);
            }
        }

        vm.stopPrank();
    }

    function testFuzzGetAllProperties(string calldata _key, string calldata _value, uint256 _count) public {
        // Constrain inputs to valid ranges
        vm.assume(bytes(_key).length >= 1 && bytes(_key).length <= 30);
        vm.assume(bytes(_value).length >= 1 && bytes(_value).length <= 2046);

        vm.startPrank(user1);

        noteManagement.createNote("Test Note", "Test Content");
        uint256 count = _count % 20;

        // Add properties
        for (uint256 i = 0; i < count; i++) {
            noteManagement.addProperty(
                0, string.concat(_key, Strings.toString(i)), string.concat(_value, Strings.toString(i))
            );
        }

        (string[] memory keys, string[] memory values) = noteManagement.getAllProperties(0);

        assertEq(keys.length, count);
        assertEq(values.length, count);

        for (uint256 i = 0; i < count; i++) {
            string memory expectedKey = string.concat(_key, Strings.toString(i));
            string memory expectedValue = string.concat(_value, Strings.toString(i));
            assertEq(keys[i], expectedKey);
            assertEq(values[i], expectedValue);
        }

        vm.stopPrank();
    }
}

/**
 * @title RandomArray
 * @dev Helper contract for generating shuffled arrays for testing property deletion
 */
contract RandomArray {
    /**
     * @dev Generates and shuffles an array of sequential numbers using Fisher-Yates algorithm
     * @param count The size of the array to generate
     * @return A shuffled array of numbers from 0 to count-1
     */
    function generateAndShuffle(uint256 count) public view returns (uint256[] memory) {
        require(count > 0 && count <= 1000, "invalid count");

        // Initialize array
        uint256[] memory arr = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            arr[i] = i;
        }

        // Fisher-Yates shuffle
        for (uint256 i = 0; i < count; i++) {
            // Generate random index j ∈ [i, count)
            uint256 j =
                i
                + (uint256(
                        keccak256(
                            abi.encodePacked(
                                block.prevrandao, // More secure randomness source than blockhash
                                msg.sender,
                                i,
                                block.timestamp
                            )
                        )
                    )
                    % (count - i));

            // Swap arr[i] with arr[j]
            (arr[i], arr[j]) = (arr[j], arr[i]);
        }

        return arr;
    }
}
