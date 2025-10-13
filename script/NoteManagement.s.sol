// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NoteManagement} from "../src/NoteManagement.sol";

contract NoteManagementScript is Script {
    NoteManagement public note;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 部署 Note 合约
        note = new NoteManagement();

        console.log("NoteManagement contract deployed at:", address(note));

        vm.stopBroadcast();
    }
}
