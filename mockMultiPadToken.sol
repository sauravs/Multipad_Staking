// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;


import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/ERC20.sol';

contract MMultipad is ERC20 {
    
    
constructor() ERC20('Mock Multipad Token', 'MMPAD') public {

      _mint(msg.sender , 100000000 * 10 ** 18);
 
}
    
}
