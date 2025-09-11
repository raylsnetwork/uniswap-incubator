// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/SuitabilityVerifier.sol";

/**
 * @title DeploySuitabilityVerifier
 * @dev Script para deploy do contrato SuitabilityVerifier
 */
contract DeploySuitabilityVerifier is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy do contrato SuitabilityVerifier
        SuitabilityVerifier suitabilityVerifier = new SuitabilityVerifier();
        
        vm.stopBroadcast();
        
        console.log("SuitabilityVerifier deployed at:", address(suitabilityVerifier));
        
        // Salvar endereço do contrato para uso posterior
        string memory deploymentData = vm.toString(address(suitabilityVerifier));
        vm.writeFile("deployments/SuitabilityAssessmentVerifier.txt", deploymentData);
        
        console.log("Deployment address saved to: deployments/SuitabilityVerifier.txt");
    }
}
