// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Note} from "../src/NoteManagement.sol";

contract NoteManagementScript is Script {
    Note public note;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 部署 Note 合约
        note = new Note();
        
        console.log("Note contract deployed at:", address(note));

        vm.stopBroadcast();
    }
}
