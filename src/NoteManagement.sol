// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title NoteManagement
 * @dev A decentralized note management system that allows users to create, update, and delete notes with custom properties.
 * Features include user isolation, property management, pagination, and gas-optimized operations.
 * This contract is UUPS upgradeable.
 */
contract NoteManagement is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /**
     * @dev Structure representing a note record with all its metadata
     */
    struct NoteRecord {
        uint256 id; // Unique identifier for the note
        uint256 timestamp; // Last modification timestamp
        address owner; // Address of the note owner
        bool isValid; // Flag indicating if the note is active (not deleted)
        string title; // Note title
        string content; // Note content
        string[] propertyKeys; // Array of property keys for this note
    }

    /// @dev Minimum allowed page size for pagination
    uint256 private constant NOTE_PAGE_SIZE_MIN = 1;
    /// @dev Maximum allowed page size for pagination
    uint256 private constant NOTE_PAGE_SIZE_MAX = 20;

    /// @dev Minimum allowed length for note titles
    uint256 private constant TITLE_LENGTH_MIN = 1;
    /// @dev Maximum allowed length for note titles
    uint256 private constant TITLE_LENGTH_MAX = 256;

    /// @dev Minimum allowed length for note content (0 allows empty content)
    uint256 private constant CONTENT_LENGTH_MIN = 0;
    /// @dev Maximum allowed length for note content
    uint256 private constant CONTENT_LENGTH_MAX = 20480;

    /// @dev Minimum allowed length for property keys
    uint256 private constant PROPERTY_KEY_LENGTH_MIN = 1;
    /// @dev Maximum allowed length for property keys
    uint256 private constant PROPERTY_KEY_LENGTH_MAX = 32;

    /// @dev Minimum allowed length for property values
    uint256 private constant PROPERTY_VALUE_LENGTH_MIN = 1;
    /// @dev Maximum allowed length for property values
    uint256 private constant PROPERTY_VALUE_LENGTH_MAX = 2048;

    /// @dev Maximum number of properties allowed per note to prevent gas limit issues
    uint256 private constant MAX_PROPERTIES_PER_NOTE = 32;

    /// @dev Global array storing all notes (including deleted ones)
    NoteRecord[] private notes;

    /// @dev Mapping from user address to array of their note IDs for fast lookup
    mapping(address => uint256[]) private userNoteIds;

    /// @dev Mapping from note ID to property key to property value
    mapping(uint256 => mapping(string => string)) private noteProperties;

    /// @dev Mapping to track existence of properties for efficient checking
    mapping(uint256 => mapping(string => bool)) private notePropertyExists;

    /// @dev Mapping from note ID to property key to array index for O(1) deletion
    mapping(uint256 => mapping(string => uint256)) private notePropertiesKeyIndices;

    /// @dev Counter for generating unique note IDs
    uint256 private nextNoteId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the deployer as the initial owner
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    /**
     * @dev Authorizes the upgrade of the contract
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier noteShouldBeValid(uint256 _id) {
        _noteShouldBeValid(_id);
        _;
    }

    function _noteShouldBeValid(uint256 _id) internal view {
        require(_id < notes.length, "Note does not exist");
        require(notes[_id].isValid == true, "Note is deleted");
    }

    modifier noteOwnerRequired(uint256 _id) {
        _noteOwnerRequired(_id);
        _;
    }

    function _noteOwnerRequired(uint256 _id) internal view {
        require(notes[_id].owner == msg.sender, "Not the note owner");
    }

    modifier validString(string memory _str, uint256 _min, uint256 _max) {
        _validString(_str, _min, _max);
        _;
    }

    function _validString(string memory _str, uint256 _min, uint256 _max) internal pure {
        require(bytes(_str).length >= _min && bytes(_str).length <= _max, "Invalid string length");
    }

    /// @dev Emitted when a new note is created
    /// @param id The ID of the created note
    /// @param owner The address of the note owner
    /// @param timestamp The creation timestamp
    event NoteCreated(uint256 indexed id, address indexed owner, uint256 timestamp);

    /// @dev Emitted when a note is updated
    /// @param id The ID of the updated note
    /// @param timestamp The update timestamp
    event NoteUpdated(uint256 indexed id, uint256 timestamp);

    /// @dev Emitted when a note is deleted
    /// @param id The ID of the deleted note
    event NoteDeleted(uint256 indexed id);

    /**
     * @dev Creates a new note with the specified title and content
     * @param _title The title of the note (must be between 1-256 characters)
     * @param _content The content of the note (must be between 0-20480 characters)
     */
    function createNote(string memory _title, string memory _content)
        public
        validString(_title, TITLE_LENGTH_MIN, TITLE_LENGTH_MAX)
        validString(_content, CONTENT_LENGTH_MIN, CONTENT_LENGTH_MAX)
    {
        uint256 noteId = nextNoteId++;

        notes.push(
            NoteRecord({
                id: noteId,
                owner: msg.sender,
                title: _title,
                content: _content,
                isValid: true,
                timestamp: block.timestamp,
                propertyKeys: new string[](0)
            })
        );

        userNoteIds[msg.sender].push(noteId);

        emit NoteCreated(noteId, msg.sender, block.timestamp);
    }

    /**
     * @dev Retrieves a note by its global ID
     * @param _id The ID of the note to retrieve
     * @return The note record containing all note data
     */
    function getNoteById(uint256 _id) public view noteShouldBeValid(_id) returns (NoteRecord memory) {
        return notes[_id];
    }

    /**
     * @dev Retrieves a paginated list of notes for the calling user
     * @param offset The starting index for pagination
     * @param limit The maximum number of notes to return (1-20)
     * @return userNotes Array of note records for the current page
     * @return nextOffset The starting index for the next page
     * @return hasMore Boolean indicating if more notes are available
     */
    function getUserNotesWithPage(uint256 offset, uint256 limit)
        public
        view
        returns (NoteRecord[] memory userNotes, uint256 nextOffset, bool hasMore)
    {
        require(limit >= NOTE_PAGE_SIZE_MIN && limit <= NOTE_PAGE_SIZE_MAX, "Invalid limit");
        uint256[] memory noteIds = userNoteIds[msg.sender];
        uint256 totalNotes = noteIds.length;

        if (offset >= totalNotes) {
            return (new NoteRecord[](0), totalNotes, false);
        }

        uint256 endIndex = offset + limit;
        if (endIndex > totalNotes) {
            endIndex = totalNotes;
        }

        uint256 resultLength = endIndex - offset;
        userNotes = new NoteRecord[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            userNotes[i] = notes[noteIds[offset + i]];
        }

        return (userNotes, endIndex, endIndex < totalNotes);
    }

    /**
     * @dev Updates an existing note's title and content
     * @param _id The ID of the note to update
     * @param _title The new title for the note (must be between 1-256 characters)
     * @param _newContent The new content for the note (must be between 0-20480 characters)
     */
    function updateNote(uint256 _id, string memory _title, string memory _newContent)
        public
        noteShouldBeValid(_id)
        noteOwnerRequired(_id)
        validString(_title, TITLE_LENGTH_MIN, TITLE_LENGTH_MAX)
        validString(_newContent, CONTENT_LENGTH_MIN, CONTENT_LENGTH_MAX)
    {
        NoteRecord storage note = notes[_id];
        note.title = _title;
        note.content = _newContent;
        note.timestamp = block.timestamp;

        emit NoteUpdated(_id, block.timestamp);
    }

    /**
     * @dev Deletes a note and all its associated data, with complete storage cleanup for gas refunds
     * @param _id The ID of the note to delete
     */
    function deleteNote(uint256 _id) public virtual noteShouldBeValid(_id) noteOwnerRequired(_id) {
        // Clean up all property data to get gas refunds
        string[] memory keys = notes[_id].propertyKeys;
        for (uint256 i = 0; i < keys.length; i++) {
            delete noteProperties[_id][keys[i]];
            delete notePropertyExists[_id][keys[i]];
            delete notePropertiesKeyIndices[_id][keys[i]];
        }

        // Remove from user's note list using swap-and-pop for O(1) deletion
        uint256[] storage noteIds = userNoteIds[msg.sender];
        for (uint256 i = 0; i < noteIds.length; i++) {
            if (noteIds[i] == _id) {
                noteIds[i] = noteIds[noteIds.length - 1];
                noteIds.pop();
                break;
            }
        }

        // Delete the entire struct to get gas refunds
        delete notes[_id];
        emit NoteDeleted(_id);
    }

    /**
     * @dev Adds or updates a property for a note
     * @param _id The ID of the note to add the property to
     * @param _key The property key (must be between 1-32 characters)
     * @param _value The property value (must be between 1-2048 characters)
     */
    function addProperty(uint256 _id, string memory _key, string memory _value)
        public
        noteShouldBeValid(_id)
        noteOwnerRequired(_id)
        validString(_key, PROPERTY_KEY_LENGTH_MIN, PROPERTY_KEY_LENGTH_MAX)
        validString(_value, PROPERTY_VALUE_LENGTH_MIN, PROPERTY_VALUE_LENGTH_MAX)
    {
        NoteRecord storage note = notes[_id];

        // Only check limit for new properties, allow updating existing ones
        if (!notePropertyExists[_id][_key]) {
            require(note.propertyKeys.length < MAX_PROPERTIES_PER_NOTE, "Too many properties");
            notePropertyExists[_id][_key] = true;
            notePropertiesKeyIndices[_id][_key] = note.propertyKeys.length;
            note.propertyKeys.push(_key);
        }

        noteProperties[_id][_key] = _value;
    }

    /**
     * @dev Deletes a property from a note using O(1) array deletion
     * @param _id The ID of the note to delete the property from
     * @param _key The key of the property to delete
     */
    function deleteProperty(uint256 _id, string memory _key) public noteShouldBeValid(_id) noteOwnerRequired(_id) {
        require(notePropertyExists[_id][_key], "Property does not exist");

        uint256 keyIndex = notePropertiesKeyIndices[_id][_key];
        string[] storage keys = notes[_id].propertyKeys;

        // Clean up all mappings
        delete noteProperties[_id][_key];
        delete notePropertiesKeyIndices[_id][_key];
        delete notePropertyExists[_id][_key];

        // O(1) deletion: swap with last element and pop
        if (keyIndex != keys.length - 1) {
            string memory lastKey = keys[keys.length - 1];
            keys[keyIndex] = lastKey;
            notePropertiesKeyIndices[_id][lastKey] = keyIndex; // Update moved element's index
        }
        keys.pop();
    }

    /**
     * @dev Retrieves the value of a specific property for a note
     * @param _id The ID of the note
     * @param _key The key of the property to retrieve
     * @return The value of the specified property (empty string if property doesn't exist)
     */
    function getProperty(uint256 _id, string memory _key) public view noteShouldBeValid(_id) returns (string memory) {
        return noteProperties[_id][_key];
    }

    /**
     * @dev Retrieves all properties for a note
     * @param _id The ID of the note
     * @return keys Array of all property keys for the note
     * @return values Array of all property values corresponding to the keys
     */
    function getAllProperties(uint256 _id)
        public
        view
        noteShouldBeValid(_id)
        returns (string[] memory keys, string[] memory values)
    {
        NoteRecord memory note = notes[_id];
        keys = note.propertyKeys;
        values = new string[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = noteProperties[_id][keys[i]];
        }
    }

    /**
     * @dev Returns the total number of notes ever created (including deleted ones)
     * @return The total count of notes in the system
     */
    function getTotalNotesCount() external view returns (uint256) {
        return notes.length;
    }

    /**
     * @dev Returns the number of active notes for the calling user
     * @return The count of active notes owned by the caller
     */
    function getUserNotesCount() external view returns (uint256) {
        return userNoteIds[msg.sender].length;
    }

    /**
     * @dev Returns the version of this implementation
     * @return The version number
     */
    function getVersion() public pure virtual returns (uint256) {
        return 1;
    }
}
