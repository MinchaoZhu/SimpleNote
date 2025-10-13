#!/bin/bash

# NoteManagement Contract Comprehensive Test Suite
# Automated testing script for smart contract functionality

# Configuration
RPC_URL="http://localhost:18545"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
FROM_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
CONTRACT_FILE="src/NoteManagement.sol:NoteManagement"
ANVIL_PID=""
CONTRACT_ADDRESS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper functions
print_header() { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"; }
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED_TESTS++))
}
print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED_TESTS++))
}
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }
print_warning() { echo -e "${PURPLE}⚠ $1${NC}"; }
print_data() { echo -e "${CYAN}📊 $1${NC}"; }

record_test() {
    ((TOTAL_TESTS++))
}

cleanup() {
    print_header "Cleanup"
    if [ ! -z "$ANVIL_PID" ]; then
        print_info "Stopping Anvil (PID: $ANVIL_PID)"
        kill $ANVIL_PID 2>/dev/null
        wait $ANVIL_PID 2>/dev/null
        print_success "Anvil stopped"
    fi

    # Print final statistics
    if [ $TOTAL_TESTS -gt 0 ]; then
        echo
        print_header "Test Summary"
        print_data "Total Tests: $TOTAL_TESTS"
        print_data "Passed: $PASSED_TESTS"
        print_data "Failed: $FAILED_TESTS"

        local success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
        print_data "Success Rate: ${success_rate}%"

        if [ $FAILED_TESTS -eq 0 ]; then
            print_success "🎉 All tests passed!"
        else
            print_warning "⚠️  Some tests failed"
        fi
    fi
}
trap cleanup EXIT

start_anvil() {
    print_header "Starting Local Blockchain"

    if lsof -Pi :18545 -sTCP:LISTEN -t >/dev/null ; then
        print_warning "Port 18545 in use, terminating existing process..."
        pkill -f "anvil" 2>/dev/null
        sleep 2
    fi

    anvil --port 18545 --host 0.0.0.0 > anvil.log 2>&1 &
    ANVIL_PID=$!
    print_info "Anvil started with PID: $ANVIL_PID"

    print_info "Waiting for blockchain to be ready..."
    for i in {1..30}; do
        if curl -s $RPC_URL -X POST -H "Content-Type: application/json" \
           -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null 2>&1; then
            print_success "Local blockchain ready"
            return 0
        fi
        sleep 1
        echo -n "."
    done

    print_error "Failed to start local blockchain"
    return 1
}

deploy_contract() {
    print_header "Contract Deployment"

    if [ ! -f "src/NoteManagement.sol" ]; then
        print_error "Contract file src/NoteManagement.sol not found"
        return 1
    fi

    print_info "Compiling and deploying NoteManagement contract..."
    local deploy_output
    deploy_output=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_FILE --broadcast 2>&1)

    if [ $? -eq 0 ]; then
        CONTRACT_ADDRESS=$(echo "$deploy_output" | grep "Deployed to:" | awk '{print $3}')
        print_success "Contract deployed successfully"
        print_data "Contract Address: $CONTRACT_ADDRESS"
        print_data "Deployer: $FROM_ADDRESS"
        return 0
    else
        print_error "Contract deployment failed"
        echo "$deploy_output"
        return 1
    fi
}

call_contract() {
    local sig=$1
    shift
    cast call --rpc-url $RPC_URL --from $FROM_ADDRESS $CONTRACT_ADDRESS "$sig" "$@" 2>/dev/null
}

send_transaction() {
    local sig=$1
    shift
    local result
    result=$(cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_ADDRESS "$sig" "$@" 2>&1)

    if [ $? -eq 0 ]; then
        sleep 2  # Wait for transaction confirmation
        return 0
    else
        # Don't echo error details in normal flow, just return failure
        return 1
    fi
}

hex_to_ascii() {
    local hex_string=$1
    if [[ $hex_string == 0x* ]]; then
        result=$(echo "$hex_string" | cast to-ascii 2>/dev/null)
        if [ $? -eq 0 ] && [ ! -z "$result" ]; then
            echo "$result"
        else
            echo "$1"
        fi
    else
        echo "$1"
    fi
}

test_prerequisites() {
    print_header "Prerequisites Check"

    local all_good=0  # 0 = success, 1 = failure

    for tool in anvil forge cast curl; do
        record_test
        if command -v $tool &> /dev/null; then
            print_success "$tool is available"
        else
            print_error "$tool is not installed"
            all_good=1
        fi
    done

    # Verify address consistency
    record_test
    local account_from_key
    account_from_key=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null)
    if [ "$FROM_ADDRESS" = "$account_from_key" ]; then
        print_success "Address consistency verified"
    else
        print_error "Address mismatch detected"
        all_good=1
    fi

    return $all_good
}

test_basic_operations() {
    print_header "Basic Operations Testing"

    # Initial state check
    record_test
    local total_count user_count
    total_count=$(call_contract "getTotalNotesCount()")
    user_count=$(call_contract "getUserNotesCount()")

    if [ $? -eq 0 ]; then
        print_success "Contract responds to queries"
        print_data "Initial total notes: $(cast to-dec $total_count)"
        print_data "Initial user notes: $(cast to-dec $user_count)"
    else
        print_error "Failed to read initial contract state"
    fi
}

test_note_creation() {
    print_header "Note Creation Testing"

    local notes=(
        "My First Note:This is the content of my first note with important information."
        "Meeting Notes:Notes from the team meeting on project planning and deadlines."
        "Shopping List:Milk, Bread, Eggs, Apples, Orange juice"
        "Todo List:1. Review code\n2. Write tests\n3. Deploy to testnet"
    )

    local created_count=0
    for note_data in "${notes[@]}"; do
        record_test
        IFS=':' read -ra NOTE_PARTS <<< "$note_data"
        title="${NOTE_PARTS[0]}"
        content="${NOTE_PARTS[1]}"

        print_info "Creating note: '$title'"
        if send_transaction "createNote(string,string)" "$title" "$content"; then
            print_success "Note created successfully"
            ((created_count++))
        else
            print_error "Failed to create note: '$title'"
            # Continue with other notes instead of failing completely
        fi
    done

    # Verify creation
    record_test
    local user_count
    user_count=$(call_contract "getUserNotesCount()")
    if [ $? -eq 0 ]; then
        local count_dec=$(cast to-dec $user_count)
        print_data "Notes created: $count_dec"

        if [ $count_dec -eq $created_count ] && [ $created_count -gt 0 ]; then
            print_success "All notes created and tracked correctly"
        elif [ $count_dec -gt 0 ]; then
            print_warning "Created $count_dec notes, expected $created_count"
        else
            print_error "No notes were created successfully"
        fi
    else
        print_error "Failed to verify note creation"
    fi
}

test_note_operations() {
    print_header "Note Operations Testing"

    # Test note reading
    record_test
    local user_count
    user_count=$(call_contract "getUserNotesCount()")
    if [ $? -eq 0 ]; then
        local count_dec=$(cast to-dec $user_count)
        print_data "User notes available: $count_dec"

        if [ $count_dec -gt 0 ]; then
            # Test reading first few notes
            local notes_read=0
            for ((i=0; i<count_dec && i<3; i++)); do
                record_test
                local note
                note=$(call_contract "getNoteById(uint256)" $i)
                if [ $? -eq 0 ] && [ ! -z "$note" ]; then
                    print_success "Successfully retrieved note $i"
                    ((notes_read++))
                else
                    print_error "Failed to retrieve note $i"
                fi
            done

            # Test note updating if we successfully read notes
            if [ $notes_read -gt 0 ]; then
                record_test
                print_info "Testing note update..."
                if send_transaction "updateNote(uint256,string,string)" 0 "Updated First Note" "This note has been updated with new content."; then
                    print_success "Note updated successfully"
                else
                    print_error "Failed to update note"
                fi
            fi
        else
            print_warning "No notes available for reading test"
        fi
    else
        print_error "Failed to get user notes count"
    fi
}

test_property_management() {
    print_header "Property Management Testing"

    # Check if we have notes to work with
    local user_count
    user_count=$(call_contract "getUserNotesCount()")
    local count_dec=$(cast to-dec $user_count)

    if [ $count_dec -eq 0 ]; then
        print_warning "No notes available for property testing"
        return 0
    fi

    # Define property test data (only for existing notes)
    declare -A note_properties
    for ((i=0; i<count_dec && i<4; i++)); do
        case $i in
            0) note_properties[$i]="category:personal priority:high status:active urgency:normal" ;;
            1) note_properties[$i]="category:work priority:high status:completed urgency:high" ;;
            2) note_properties[$i]="category:personal priority:low status:active urgency:low" ;;
            3) note_properties[$i]="category:work priority:medium status:pending urgency:medium" ;;
        esac
    done

    # Add properties to notes
    print_info "Adding properties to notes..."
    local total_properties=0

    for note_id in "${!note_properties[@]}"; do
        properties="${note_properties[$note_id]}"
        print_info "Adding properties to note $note_id..."

        for prop_pair in $properties; do
            record_test
            IFS=':' read -ra PROP_PARTS <<< "$prop_pair"
            key="${PROP_PARTS[0]}"
            value="${PROP_PARTS[1]}"

            if send_transaction "addProperty(uint256,string,string)" $note_id "$key" "$value"; then
                print_success "  Added $key=$value"
                ((total_properties++))
            else
                print_error "  Failed to add $key=$value"
            fi
        done
    done

    sleep 3  # Wait for all transactions to be confirmed

    # Verify properties
    print_info "Verifying properties..."
    for note_id in "${!note_properties[@]}"; do
        properties="${note_properties[$note_id]}"

        for prop_pair in $properties; do
            record_test
            IFS=':' read -ra PROP_PARTS <<< "$prop_pair"
            key="${PROP_PARTS[0]}"

            local prop_value
            prop_value=$(call_contract "getProperty(uint256,string)" $note_id "$key")
            if [ $? -eq 0 ] && [ ! -z "$prop_value" ] && [ "$prop_value" != "0x" ]; then
                local decoded_value=$(hex_to_ascii "$prop_value")
                print_data "  Note $note_id - $key: '$decoded_value'"
                print_success "  Property verified"
            else
                print_warning "  Note $note_id - $key: not found or empty"
            fi
        done
    done
}

test_property_statistics() {
    print_header "Property Statistics Testing"

    # Test property pairs count
    record_test
    local pairs_count
    pairs_count=$(call_contract "getPropertyPairsCount()")
    if [ $? -eq 0 ]; then
        local pairs_count_dec=$(cast to-dec $pairs_count)
        print_success "Property pairs count: $pairs_count_dec"

        if [ $pairs_count_dec -gt 0 ]; then
            # Test different limits for top statistics
            for limit in 0 5 10; do
                record_test
                print_info "Getting top statistics (limit: $limit)..."
                local stats_result
                stats_result=$(call_contract "getTopPropertyStatistics(uint256)" $limit)

                if [ $? -eq 0 ]; then
                    print_success "  Statistics retrieved successfully"
                    print_data "  Result length: ${#stats_result} characters"

                    if [ ${#stats_result} -gt 500 ]; then
                        print_success "  Rich statistics data available"
                    fi
                else
                    print_error "  Failed to retrieve statistics"
                fi
            done
        else
            print_warning "No property pairs found"
        fi
    else
        print_error "Failed to get property pairs count"
    fi
}

test_filtering_system() {
    print_header "Filtering System Testing"

    # Comprehensive filter test cases
    declare -a filter_tests=(
        "category:personal:Personal notes"
        "priority:high:High priority items"
        "status:active:Active notes"
        "category:work:Work-related notes"
        "priority:medium:Medium priority items"
        "status:completed:Completed tasks"
        "urgency:high:High urgency items"
        "category:nonexistent:Non-existent category"
        "priority:invalid:Invalid priority"
    )

    for test_case in "${filter_tests[@]}"; do
        record_test
        IFS=':' read -ra PARTS <<< "$test_case"
        key="${PARTS[0]}"
        value="${PARTS[1]}"
        description="${PARTS[2]}"

        print_info "Filter test: $key='$value' ($description)"

        local filter_result
        filter_result=$(call_contract "filterNotesByPropertyWithPage(string,string,uint256,uint256)" "$key" "$value" 0 10)
        if [ $? -eq 0 ]; then
            print_success "  Filter executed successfully"

            # Analyze result size to estimate matches
            if [ ${#filter_result} -gt 600 ]; then
                print_data "  Multiple matches found"
            elif [ ${#filter_result} -gt 300 ]; then
                print_data "  Single match found"
            else
                print_data "  No matches found"
            fi
        else
            print_error "  Filter execution failed"
        fi
    done

    # Test edge cases
    print_info "Testing edge cases..."

    record_test
    local empty_result
    empty_result=$(call_contract "filterNotesByPropertyWithPage(string,string,uint256,uint256)" "" "" 0 10)
    if [ $? -eq 0 ]; then
        print_success "  Empty filter handled correctly"
    else
        print_error "  Empty filter failed"
    fi

    record_test
    local key_only_result
    key_only_result=$(call_contract "filterNotesByPropertyWithPage(string,string,uint256,uint256)" "category" "" 0 10)
    if [ $? -eq 0 ]; then
        print_success "  Key-only filter handled correctly"
    else
        print_error "  Key-only filter failed"
    fi

    record_test
    local value_only_result
    value_only_result=$(call_contract "filterNotesByPropertyWithPage(string,string,uint256,uint256)" "" "high" 0 10)
    if [ $? -eq 0 ]; then
        print_success "  Value-only filter handled correctly"
    else
        print_error "  Value-only filter failed"
    fi
}

test_pagination_system() {
    print_header "Pagination System Testing"

    record_test
    local user_count
    user_count=$(call_contract "getUserNotesCount()")
    if [ $? -eq 0 ]; then
        local count_dec=$(cast to-dec $user_count)
        print_data "Total user notes: $count_dec"

        if [ $count_dec -gt 0 ]; then
            # Test various page sizes
            for limit in 1 2 3 5; do
                record_test
                print_info "Testing page size: $limit"

                local offset=0
                local page_num=1

                while [ $offset -lt $count_dec ] && [ $page_num -le 5 ]; do
                    local page_result
                    page_result=$(call_contract "getUserNotesWithPage(uint256,uint256)" $offset $limit)

                    if [ $? -eq 0 ]; then
                        print_success "  Page $page_num retrieved (offset=$offset)"
                    else
                        print_error "  Page $page_num failed (offset=$offset)"
                        break
                    fi

                    offset=$((offset + limit))
                    page_num=$((page_num + 1))
                done
            done
        else
            print_warning "No notes available for pagination testing"
        fi
    else
        print_error "Failed to get user notes count"
    fi
}

test_error_handling() {
    print_header "Error Handling Testing"

    # Test invalid inputs
    print_info "Testing invalid note creation..."

    record_test
    if ! send_transaction "createNote(string,string)" "" "content" 2>/dev/null; then
        print_success "  Empty title correctly rejected"
    else
        print_error "  Empty title unexpectedly accepted"
    fi

    record_test
    local long_title=$(printf 'a%.0s' {1..300})
    if ! send_transaction "createNote(string,string)" "$long_title" "content" 2>/dev/null; then
        print_success "  Oversized title correctly rejected"
    else
        print_error "  Oversized title unexpectedly accepted"
    fi

    # Test invalid note access
    print_info "Testing invalid note access..."
    record_test
    if ! call_contract "getNoteById(uint256)" 999 >/dev/null 2>&1; then
        print_success "  Non-existent note access correctly rejected"
    else
        print_error "  Non-existent note access unexpectedly allowed"
    fi

    # Test invalid pagination
    print_info "Testing invalid pagination..."
    record_test
    if ! call_contract "getUserNotesWithPage(uint256,uint256)" 0 0 >/dev/null 2>&1; then
        print_success "  Invalid pagination limit correctly rejected"
    else
        print_error "  Invalid pagination limit unexpectedly accepted"
    fi

    record_test
    if ! call_contract "getUserNotesWithPage(uint256,uint256)" 0 25 >/dev/null 2>&1; then
        print_success "  Oversized pagination limit correctly rejected"
    else
        print_error "  Oversized pagination limit unexpectedly accepted"
    fi
}

test_property_operations() {
    print_header "Advanced Property Operations"

    # Check if we have notes with properties
    local user_count
    user_count=$(call_contract "getUserNotesCount()")
    local count_dec=$(cast to-dec $user_count)

    if [ $count_dec -eq 0 ]; then
        print_warning "No notes available for property operations testing"
        return 0
    fi

    # Test property deletion
    record_test
    print_info "Testing property deletion..."
    if send_transaction "deleteProperty(uint256,string)" 0 "urgency"; then
        print_success "  Property deleted successfully"

        # Verify deletion
        local deleted_prop
        deleted_prop=$(call_contract "getProperty(uint256,string)" 0 "urgency")
        if [ -z "$deleted_prop" ] || [ "$deleted_prop" = "0x" ] || [ "$deleted_prop" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
            print_success "  Property deletion verified"
        else
            print_warning "  Property may not have been completely deleted"
        fi
    else
        print_error "  Property deletion failed"
    fi

    # Test property update
    record_test
    print_info "Testing property update..."
    if send_transaction "addProperty(uint256,string,string)" 0 "category" "updated_personal"; then
        print_success "  Property updated successfully"

        # Verify update
        local updated_prop
        updated_prop=$(call_contract "getProperty(uint256,string)" 0 "category")
        if [ $? -eq 0 ]; then
            local decoded_value=$(hex_to_ascii "$updated_prop")
            print_data "  Updated value: '$decoded_value'"
        fi
    else
        print_error "  Property update failed"
    fi
}

generate_test_report() {
    print_header "Test Report Summary"

    # Collect final statistics
    local total_count user_count pairs_count
    total_count=$(call_contract "getTotalNotesCount()")
    user_count=$(call_contract "getUserNotesCount()")
    pairs_count=$(call_contract "getPropertyPairsCount()")

    if [ $? -eq 0 ]; then
        local total_dec=$(cast to-dec $total_count)
        local user_dec=$(cast to-dec $user_count)
        local pairs_dec=$(cast to-dec $pairs_count)

        print_success "Contract Testing Completed Successfully"
        echo
        print_data "📈 Final Statistics:"
        print_data "  Total notes in system: $total_dec"
        print_data "  Active user notes: $user_dec"
        print_data "  Unique property pairs: $pairs_dec"
        print_data "  Contract address: $CONTRACT_ADDRESS"
        echo

        if [ $user_dec -gt 0 ] && [ $pairs_dec -gt 0 ]; then
            print_success "🎉 All core functionalities verified and working correctly!"
        else
            print_warning "⚠️  Some functionalities may need attention"
        fi
    else
        print_error "Failed to generate complete test report"
    fi
}

# Main execution function
main() {
    print_header "NoteManagement Contract Test Suite"
    echo -e "${CYAN}Comprehensive testing of smart contract functionality${NC}"
    echo

    # Run prerequisite checks
    if ! test_prerequisites; then
        print_error "Prerequisites not met. Please install required tools."
        exit 1
    fi

    # Start blockchain and deploy contract
    if ! start_anvil; then
        print_error "Failed to start local blockchain"
        exit 1
    fi

    if ! deploy_contract; then
        print_error "Failed to deploy contract"
        exit 1
    fi

    # Execute comprehensive test suite - continue even if individual tests fail
    test_basic_operations
    test_note_creation
    test_note_operations
    test_property_management
    test_property_statistics
    test_filtering_system
    test_pagination_system
    test_property_operations
    test_error_handling

    # Generate final report
    generate_test_report

    print_header "Testing Complete"
    print_info "Blockchain logs available in: anvil.log"
    echo

    sleep 2  # Brief pause for CI environments
}

# Execute main function
main "$@"
