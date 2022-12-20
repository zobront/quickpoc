// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/CapitalistPigs/contracts/CapitalistPigs.sol";

contract CapitalistPigsPOC is Test {
  CapitalistPigs c = CapitalistPigs(0x78D72E60BaE892F97b97fEBAE5886DaB2eF0cbC8);

  function testCapitalistPigsPOC() public {
      vm.createSelectFork('https://mainnet.infura.io/v3/fb419f740b7e401bad5bec77d0d285a5');
      assert(address(c) == 0x78D72E60BaE892F97b97fEBAE5886DaB2eF0cbC8);
  }
}
