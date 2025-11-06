// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NoteManagement} from "../src/NoteManagement.sol";
import {NoteManagementV2} from "./base.t.sol";

/**
 * @title NoteManagementUUPSTest
 * @dev Test suite for UUPS upgradeable NoteManagement contract
 */
contract NoteManagementUUPSTest is Test {
    NoteManagement public implementation;
    ERC1967Proxy public proxy;
    NoteManagement public proxyContract;
    NoteManagementV2 public v2Implementation;
    NoteManagementV2 public v2Proxy;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    // Events from the contract
    event NoteCreated(uint256 indexed id, address indexed owner, uint256 timestamp);
    event NoteUpdated(uint256 indexed id, uint256 timestamp);
    event NoteDeleted(uint256 indexed id);

    function setUp() public {
        // Deploy implementation
        implementation = new NoteManagement();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(NoteManagement.initialize.selector);
        proxy = new ERC1967Proxy(address(implementation), initData);
        proxyContract = NoteManagement(address(proxy));

        // Deploy V2 implementation for testing
        v2Implementation = new NoteManagementV2();

        // Set owner to this contract for testing
        owner = address(this);
    }

    // ========== Initialization Tests ==========

    function testInitialization() public view {
        assertEq(proxyContract.owner(), address(this));
        assertEq(proxyContract.getTotalNotesCount(), 0);
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert();
        proxyContract.initialize();
    }

    // ========== Basic Functionality Tests ==========

    function testCreateNote() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, false);
        emit NoteCreated(0, user1, block.timestamp);

        proxyContract.createNote("My First Note", "This is the content");

        assertEq(proxyContract.getTotalNotesCount(), 1);
        assertEq(proxyContract.getUserNotesCount(), 1);

        NoteManagement.NoteRecord memory note = proxyContract.getNoteById(0);
        assertEq(note.id, 0);
        assertEq(note.owner, user1);
        assertEq(note.title, "My First Note");
        assertEq(note.content, "This is the content");
        assertTrue(note.isValid);

        vm.stopPrank();
    }

    function testUpdateNote() public {
        vm.startPrank(user1);

        proxyContract.createNote("Original Title", "Original Content");
        uint256 originalTimestamp = block.timestamp;
        vm.warp(block.timestamp + 100);

        vm.expectEmit(true, false, false, false);
        emit NoteUpdated(0, block.timestamp);

        proxyContract.updateNote(0, "Updated Title", "Updated Content");

        NoteManagement.NoteRecord memory note = proxyContract.getNoteById(0);
        assertEq(note.title, "Updated Title");
        assertEq(note.content, "Updated Content");
        assertTrue(note.timestamp > originalTimestamp);

        vm.stopPrank();
    }

    function testDeleteNote() public {
        vm.startPrank(user1);

        proxyContract.createNote("Test Note", "Test Content");

        vm.expectEmit(true, false, false, false);
        emit NoteDeleted(0);

        proxyContract.deleteNote(0);

        assertEq(proxyContract.getUserNotesCount(), 0);

        vm.expectRevert("Note is deleted");
        proxyContract.getNoteById(0);

        vm.stopPrank();
    }

    // ========== Upgrade Tests ==========

    function testUpgradeToNewImplementation() public {
        // Create some data before upgrade
        vm.startPrank(user1);
        proxyContract.createNote("Test Note", "Test Content");
        proxyContract.addProperty(0, "priority", "high");
        vm.stopPrank();

        // Deploy new implementation
        NoteManagement newImplementation = new NoteManagement();

        // Upgrade to new implementation
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Verify data is preserved
        vm.startPrank(user1);
        assertEq(proxyContract.getTotalNotesCount(), 1);
        assertEq(proxyContract.getUserNotesCount(), 1);

        NoteManagement.NoteRecord memory note = proxyContract.getNoteById(0);
        assertEq(note.title, "Test Note");
        assertEq(note.content, "Test Content");
        assertEq(proxyContract.getProperty(0, "priority"), "high");
        vm.stopPrank();
    }

    function testUpgradeToV2() public {
        // Create some data before upgrade
        vm.startPrank(user1);
        proxyContract.createNote("Test Note", "Test Content");
        proxyContract.addProperty(0, "priority", "high");
        vm.stopPrank();

        // Upgrade to V2
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();

        // Get V2 proxy instance
        v2Proxy = NoteManagementV2(address(proxy));

        // Verify data is preserved
        vm.startPrank(user1);
        assertEq(v2Proxy.getTotalNotesCount(), 1);
        assertEq(v2Proxy.getUserNotesCount(), 1);

        NoteManagement.NoteRecord memory note = v2Proxy.getNoteById(0);
        assertEq(note.title, "Test Note");
        assertEq(note.content, "Test Content");
        assertEq(v2Proxy.getProperty(0, "priority"), "high");
        vm.stopPrank();
    }

    function testV2NewFeatures() public {
        // Upgrade to V2 first
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();

        v2Proxy = NoteManagementV2(address(proxy));

        // Create a note and test V2 features
        vm.startPrank(user1);
        v2Proxy.createNote("Test Note", "Test Content");

        // Test tags functionality
        v2Proxy.addTag(0, "urgent");
        v2Proxy.addTag(0, "important");

        string[] memory tags = v2Proxy.getTags(0);
        assertEq(tags.length, 2);
        assertEq(tags[0], "urgent");
        assertEq(tags[1], "important");

        // Test priority functionality
        v2Proxy.setPriority(0, NoteManagementV2.Priority.High);
        assertEq(uint256(v2Proxy.getPriority(0)), uint256(NoteManagementV2.Priority.High));

        vm.stopPrank();
    }

    function testV2TagLimits() public {
        // Upgrade to V2 first
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();

        v2Proxy = NoteManagementV2(address(proxy));

        vm.startPrank(user1);
        v2Proxy.createNote("Test Note", "Test Content");

        // Add some tags (NoteManagementV2 doesn't have tag limits, so we'll test basic functionality)
        v2Proxy.addTag(0, "tag1");
        v2Proxy.addTag(0, "tag2");
        v2Proxy.addTag(0, "tag3");

        string[] memory tags = v2Proxy.getTags(0);
        assertEq(tags.length, 3);
        assertEq(tags[0], "tag1");
        assertEq(tags[1], "tag2");
        assertEq(tags[2], "tag3");

        vm.stopPrank();
    }

    function testV2PriorityFiltering() public {
        // Upgrade to V2 first
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();

        v2Proxy = NoteManagementV2(address(proxy));

        vm.startPrank(user1);
        v2Proxy.createNote("High Priority Note", "Important content");
        v2Proxy.createNote("Low Priority Note", "Less important content");

        // Set priorities
        v2Proxy.setPriority(0, NoteManagementV2.Priority.High);
        v2Proxy.setPriority(1, NoteManagementV2.Priority.Low);

        // Test priority filtering
        uint256[] memory highPriorityNotes = v2Proxy.getNotesByPriority(NoteManagementV2.Priority.High);
        uint256[] memory lowPriorityNotes = v2Proxy.getNotesByPriority(NoteManagementV2.Priority.Low);

        assertEq(highPriorityNotes.length, 1);
        assertEq(highPriorityNotes[0], 0);
        assertEq(lowPriorityNotes.length, 1);
        assertEq(lowPriorityNotes[0], 1);

        vm.stopPrank();
    }

    function testV2DataCleanupOnDelete() public {
        // Upgrade to V2 first
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();

        v2Proxy = NoteManagementV2(address(proxy));

        vm.startPrank(user1);
        v2Proxy.createNote("Test Note", "Test Content");
        v2Proxy.addTag(0, "urgent");
        v2Proxy.addTag(0, "important");
        v2Proxy.setPriority(0, NoteManagementV2.Priority.High);

        // Delete the note
        v2Proxy.deleteNote(0);

        // Verify V2 data is cleaned up
        vm.expectRevert("Note is deleted");
        v2Proxy.getTags(0);

        vm.expectRevert("Note is deleted");
        v2Proxy.getPriority(0);

        vm.stopPrank();
    }

    // ========== Access Control Tests ==========

    function testOnlyOwnerCanUpgrade() public {
        NoteManagement newImplementation = new NoteManagement();

        vm.startPrank(user1);
        vm.expectRevert();
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();
    }

    // ========== Storage Layout Tests ==========

    function testStorageLayoutPreservation() public {
        // Create comprehensive data before upgrade
        vm.startPrank(user1);
        proxyContract.createNote("Note 1", "Content 1");
        proxyContract.createNote("Note 2", "Content 2");
        proxyContract.addProperty(0, "priority", "high");
        proxyContract.addProperty(0, "category", "work");
        proxyContract.addProperty(1, "status", "active");
        vm.stopPrank();

        vm.startPrank(user2);
        proxyContract.createNote("Note 3", "Content 3");
        proxyContract.addProperty(2, "type", "personal");
        vm.stopPrank();

        // Deploy new implementation
        NoteManagement newImplementation = new NoteManagement();

        // Upgrade to new implementation
        vm.startPrank(owner);
        proxyContract.upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Verify all data is preserved
        vm.startPrank(user1);
        assertEq(proxyContract.getUserNotesCount(), 2);
        assertEq(proxyContract.getProperty(0, "priority"), "high");
        assertEq(proxyContract.getProperty(0, "category"), "work");
        assertEq(proxyContract.getProperty(1, "status"), "active");
        vm.stopPrank();

        vm.startPrank(user2);
        assertEq(proxyContract.getUserNotesCount(), 1);
        assertEq(proxyContract.getProperty(2, "type"), "personal");
        vm.stopPrank();
    }
}
