// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title NoteManagement
 * @dev A decentralized note management system that allows users to create, update, and delete notes with custom properties.
 * Features include user isolation, property management, pagination, and gas-optimized operations.
 */
contract NoteManagement {
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

    /**
     * @dev Modifier to ensure a note exists and is not deleted
     * @param _id The ID of the note to validate
     */
    modifier noteShouldBeValid(uint256 _id) {
        require(_id < notes.length, "Note does not exist");
        require(notes[_id].isValid == true, "Note is deleted");
        _;
    }

    /**
     * @dev Modifier to ensure the caller is the owner of the note
     * @param _id The ID of the note to check ownership for
     */
    modifier noteOwnerRequired(uint256 _id) {
        require(notes[_id].owner == msg.sender, "Not the note owner");
        _;
    }

    /**
     * @dev Modifier to validate string length constraints
     * @param _str The string to validate
     * @param _min Minimum allowed length
     * @param _max Maximum allowed length
     */
    modifier validString(string memory _str, uint256 _min, uint256 _max) {
        require(bytes(_str).length >= _min && bytes(_str).length <= _max, "Invalid string length");
        _;
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
    function deleteNote(uint256 _id) public noteShouldBeValid(_id) noteOwnerRequired(_id) {
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

    function filterNotesByPropertyWithPage(string memory _key, string memory _value, uint256 offset, uint256 limit)
        public
        view
        returns (NoteRecord[] memory filteredNotes, uint256 nextOffset, bool hasMore)
    {
        require(limit >= NOTE_PAGE_SIZE_MIN && limit <= NOTE_PAGE_SIZE_MAX, "Invalid limit");

        uint256[] memory noteIds = userNoteIds[msg.sender];
        uint256[] memory matchingIds = new uint256[](noteIds.length);
        uint256 matchCount = 0;

        bool checkKey = bytes(_key).length > 0;
        bool checkValue = bytes(_value).length > 0;

        // First pass: find all matching notes
        for (uint256 i = 0; i < noteIds.length; i++) {
            uint256 noteId = noteIds[i];

            if (_matchesFilter(noteId, _key, _value, checkKey, checkValue)) {
                matchingIds[matchCount] = noteId;
                matchCount++;
            }
        }

        // Handle pagination
        if (offset >= matchCount) {
            return (new NoteRecord[](0), offset > matchCount ? offset : matchCount, false);
        }

        uint256 endIndex = offset + limit;
        if (endIndex > matchCount) {
            endIndex = matchCount;
        }

        uint256 resultLength = endIndex - offset;
        filteredNotes = new NoteRecord[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            filteredNotes[i] = notes[matchingIds[offset + i]];
        }

        return (filteredNotes, endIndex, endIndex < matchCount);
    }

    /**
     * @dev Internal function to check if a note matches the filter criteria
     * @param noteId The ID of the note to check
     * @param _key The key to filter by
     * @param _value The value to filter by
     * @param checkKey Whether to check the key
     * @param checkValue Whether to check the value
     * @return Whether the note matches the filter
     */
    function _matchesFilter(uint256 noteId, string memory _key, string memory _value, bool checkKey, bool checkValue)
        private
        view
        returns (bool)
    {
        if (checkKey) {
            // Check if note has the specified key
            if (!notePropertyExists[noteId][_key]) {
                return false;
            }
            if (checkValue) {
                // Check if the value matches
                return keccak256(bytes(noteProperties[noteId][_key])) == keccak256(bytes(_value));
            }
            return true;
        } else if (checkValue) {
            // Only checking value, search through all properties
            string[] memory keys = notes[noteId].propertyKeys;
            for (uint256 j = 0; j < keys.length; j++) {
                if (keccak256(bytes(noteProperties[noteId][keys[j]])) == keccak256(bytes(_value))) {
                    return true;
                }
            }
            return false;
        }

        // Neither key nor value specified, match all notes
        return true;
    }

    /**
     * @dev Returns all unique (key, value) pairs sorted by count (descending)
     * @param maxResults Maximum number of results to return (0 means return all)
     * @return keys Array of property keys
     * @return values Array of property values
     * @return counts Array of occurrence counts (sorted descending)
     */
    function getTopPropertyStatistics(uint256 maxResults)
        public
        view
        returns (string[] memory keys, string[] memory values, uint256[] memory counts)
    {
        uint256[] memory noteIds = userNoteIds[msg.sender];

        // Handle empty case
        if (noteIds.length == 0) {
            return (new string[](0), new string[](0), new uint256[](0));
        }

        // Collect statistics first
        string[] memory tempKeys = new string[](noteIds.length * MAX_PROPERTIES_PER_NOTE);
        string[] memory tempValues = new string[](noteIds.length * MAX_PROPERTIES_PER_NOTE);
        uint256[] memory tempCounts = new uint256[](noteIds.length * MAX_PROPERTIES_PER_NOTE);
        uint256 uniquePairs = 0;

        // Collect all key-value pairs
        for (uint256 i = 0; i < noteIds.length; i++) {
            uint256 noteId = noteIds[i];
            string[] memory noteKeys = notes[noteId].propertyKeys;

            for (uint256 j = 0; j < noteKeys.length; j++) {
                string memory key = noteKeys[j];
                string memory value = noteProperties[noteId][key];

                // Check if this key-value pair already exists
                bool found = false;
                for (uint256 k = 0; k < uniquePairs; k++) {
                    if (
                        keccak256(bytes(tempKeys[k])) == keccak256(bytes(key))
                            && keccak256(bytes(tempValues[k])) == keccak256(bytes(value))
                    ) {
                        tempCounts[k]++;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    tempKeys[uniquePairs] = key;
                    tempValues[uniquePairs] = value;
                    tempCounts[uniquePairs] = 1;
                    uniquePairs++;
                }
            }
        }

        // Handle case where no properties exist
        if (uniquePairs == 0) {
            return (new string[](0), new string[](0), new uint256[](0));
        }

        // Simple bubble sort by count (descending) - Fixed underflow issue
        if (uniquePairs > 1) {
            for (uint256 i = 0; i < uniquePairs - 1; i++) {
                for (uint256 j = 0; j < uniquePairs - i - 1; j++) {
                    if (tempCounts[j] < tempCounts[j + 1]) {
                        // Swap counts
                        uint256 tempCount = tempCounts[j];
                        tempCounts[j] = tempCounts[j + 1];
                        tempCounts[j + 1] = tempCount;

                        // Swap keys
                        string memory tempKey = tempKeys[j];
                        tempKeys[j] = tempKeys[j + 1];
                        tempKeys[j + 1] = tempKey;

                        // Swap values
                        string memory tempValue = tempValues[j];
                        tempValues[j] = tempValues[j + 1];
                        tempValues[j + 1] = tempValue;
                    }
                }
            }
        }

        // Determine result size
        uint256 resultSize = uniquePairs;
        if (maxResults > 0 && maxResults < uniquePairs) {
            resultSize = maxResults;
        }

        // Create result arrays
        keys = new string[](resultSize);
        values = new string[](resultSize);
        counts = new uint256[](resultSize);

        for (uint256 i = 0; i < resultSize; i++) {
            keys[i] = tempKeys[i];
            values[i] = tempValues[i];
            counts[i] = tempCounts[i];
        }
    }

    /**
     * @dev Returns the total number of unique property pairs for the user
     * @return The count of unique (key, value) pairs
     */
    function getPropertyPairsCount() public view returns (uint256) {
        (string[] memory keys,,) = getTopPropertyStatistics(0);
        return keys.length;
    }
}
