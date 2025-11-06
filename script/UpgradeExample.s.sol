// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {NoteManagement} from "../src/NoteManagement.sol";

/**
 * @title UpgradeExample
 * @dev Example script showing how to upgrade the contract
 */
contract UpgradeExample is Script {
    function run() external {
        // This is just an example - in practice you would get these addresses from deployment
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation (same as V1 for this example)
        NoteManagement newImplementation = new NoteManagement();
        console.log("New implementation deployed at:", address(newImplementation));

        // Get the proxy contract
        NoteManagement proxy = NoteManagement(proxyAddress);

        // Upgrade the contract
        proxy.upgradeToAndCall(address(newImplementation), abi.encodeWithSelector(NoteManagement.initialize.selector));

        console.log("Contract upgraded successfully!");

        // Test the upgraded contract
        NoteManagement upgradedContract = NoteManagement(proxyAddress);

        // Create a note and test basic functionality
        upgradedContract.createNote("Upgraded Note", "This note was created after upgrade");

        console.log("Total notes after upgrade:", upgradedContract.getTotalNotesCount());

        vm.stopBroadcast();
    }
}
