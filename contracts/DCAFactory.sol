pragma solidity ^0.6;

import 'https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/CloneFactory.sol';

contract DCAFactory is CloneFactory{
    
    address DCATemplate = 0x276Eb817A919414EE1b67DAf3A6C29a20f61384F;
    mapping(address => address) private users;
    
    constructor() public {
        
    }
    
    
    function createDCA() public{
        address userContract = createClone(DCATemplate);
        users[msg.sender] = userContract;
    }
    
    
    function getUsersAccount() public view returns(address){
        return users[msg.sender];
    }
    
}
