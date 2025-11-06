// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {NoteManagement} from "../src/NoteManagement.sol";

/**
 * @title NoteManagementV2
 * @dev Version 2 of NoteManagement with additional features
 * This contract demonstrates UUPS upgradeability with new functionality
 * Used for both unit tests and integration tests
 */
contract NoteManagementV2 is NoteManagement {
    /// @dev New feature: note tags
    mapping(uint256 => string[]) private noteTags;

    /// @dev New feature: note priority levels
    enum Priority {
        Low,
        Medium,
        High,
        Critical
    }
    mapping(uint256 => Priority) private notePriority;

    /// @dev Events for new features
    event NoteTagged(uint256 indexed noteId, string tag);
    event NotePrioritySet(uint256 indexed noteId, Priority priority);

    /**
     * @dev Override getVersion to return V2 version
     */
    function getVersion() public pure override returns (uint256) {
        return 2;
    }

    /**
     * @dev Add a tag to a note
     * @param _id The ID of the note
     * @param _tag The tag to add
     */
    function addTag(uint256 _id, string memory _tag) public noteShouldBeValid(_id) noteOwnerRequired(_id) {
        require(bytes(_tag).length > 0, "Tag cannot be empty");
        require(bytes(_tag).length <= 32, "Tag too long");

        noteTags[_id].push(_tag);
        emit NoteTagged(_id, _tag);
    }

    /**
     * @dev Get all tags for a note
     * @param _id The ID of the note
     * @return Array of tags
     */
    function getTags(uint256 _id) public view noteShouldBeValid(_id) returns (string[] memory) {
        return noteTags[_id];
    }

    /**
     * @dev Set priority for a note
     * @param _id The ID of the note
     * @param _priority The priority level
     */
    function setPriority(uint256 _id, Priority _priority) public noteShouldBeValid(_id) noteOwnerRequired(_id) {
        notePriority[_id] = _priority;
        emit NotePrioritySet(_id, _priority);
    }

    /**
     * @dev Get priority for a note
     * @param _id The ID of the note
     * @return The priority level
     */
    function getPriority(uint256 _id) public view noteShouldBeValid(_id) returns (Priority) {
        return notePriority[_id];
    }

    /**
     * @dev Get notes by priority
     * @param _priority The priority level to filter by
     * @return Array of note IDs with the specified priority
     */
    function getNotesByPriority(Priority _priority) public view returns (uint256[] memory) {
        // Get user notes using the inherited function
        (NoteRecord[] memory userNotes,,) = getUserNotesWithPage(0, 20); // Use reasonable limit
        uint256 count = 0;

        // Count notes with the specified priority
        for (uint256 i = 0; i < userNotes.length; i++) {
            if (notePriority[userNotes[i].id] == _priority) {
                count++;
            }
        }

        // Create result array
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < userNotes.length; i++) {
            if (notePriority[userNotes[i].id] == _priority) {
                result[index] = userNotes[i].id;
                index++;
            }
        }

        return result;
    }
}
