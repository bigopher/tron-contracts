pragma solidity ^0.4.23;

import "@evolutionland/upgraeability-using-unstructured-storage/contracts/OwnedUpgradeabilityProxy.sol";
import "./common/StandardERC223.sol";

contract DeployAndTest {
    address public testRING = new StandardERC223("RING");
    address public testKTON = new StandardERC223("KTON");

    constructor() public {
        StandardERC223(testRING).changeController(msg.sender);
        StandardERC223(testKTON).changeController(msg.sender);
        StandardERC223(testRING).setOwner(msg.sender);
        StandardERC223(testKTON).setOwner(msg.sender);
    }

}