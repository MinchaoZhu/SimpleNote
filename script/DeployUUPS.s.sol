// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NoteManagement} from "../src/NoteManagement.sol";

/**
 * @title DeployUUPS
 * @dev Deployment script for UUPS upgradeable NoteManagement contract
 */
contract DeployUUPS is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with the account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contract
        NoteManagement implementation = new NoteManagement();
        console.log("Implementation deployed at:", address(implementation));

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(NoteManagement.initialize.selector);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed at:", address(proxy));

        // Get the proxy contract instance
        NoteManagement proxyContract = NoteManagement(address(proxy));

        // Test basic functionality
        proxyContract.createNote("Test Note", "This is a test note");
        console.log("Total notes after creation:", proxyContract.getTotalNotesCount());

        vm.stopBroadcast();

        console.log("Deployment completed successfully!");
        console.log("Proxy address:", address(proxy));
        console.log("Implementation address:", address(implementation));
    }
}
