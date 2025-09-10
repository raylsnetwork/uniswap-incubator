// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./DeployHelpers.s.sol";
import "../contracts/SuitabilityVerifier.sol";

/**
 * @title DeploySuitabilityVerifier
 * @dev Script para deploy do contrato SuitabilityVerifier
 */
contract DeploySuitabilityVerifier is ScaffoldETHDeploy {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy do contrato SuitabilityVerifier
        SuitabilityVerifier suitabilityVerifier = new SuitabilityVerifier();
        
        vm.stopBroadcast();
        
        console.log("SuitabilityVerifier deployed at:", address(suitabilityVerifier));
        
        // Salvar endereço do contrato para uso posterior
        string memory deploymentData = vm.toString(address(suitabilityVerifier));
        vm.writeFile("deployments/SuitabilityVerifier.txt", deploymentData);
        
        console.log("Deployment address saved to: deployments/SuitabilityVerifier.txt");
    }
}
